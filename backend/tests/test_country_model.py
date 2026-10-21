from pathlib import Path

import pytest
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db.base import Base
from app.db.session import create_database_engine
from app.models.country import Country


@pytest.fixture
def database_engine(tmp_path: Path):
    engine = create_database_engine(f"sqlite:///{tmp_path / 'countries.db'}")

    Base.metadata.create_all(engine)

    yield engine

    engine.dispose()


def test_country_can_be_persisted(database_engine) -> None:
    with Session(database_engine) as session:
        session.add(
            Country(
                code="PT",
                name="Portugal",
                alpha3_code="PRT",
            )
        )
        session.commit()

    with Session(database_engine) as session:
        country = session.get(Country, "PT")

        assert country is not None
        assert country.code == "PT"
        assert country.name == "Portugal"
        assert country.alpha3_code == "PRT"


def test_country_code_must_be_unique(database_engine) -> None:
    with Session(database_engine) as session:
        session.add(
            Country(
                code="PT",
                name="Portugal",
                alpha3_code="PRT",
            )
        )
        session.commit()

    with Session(database_engine) as session:
        session.add(
            Country(
                code="PT",
                name="Different country",
                alpha3_code="XXX",
            )
        )

        with pytest.raises(IntegrityError):
            session.commit()

        session.rollback()


def test_alpha3_code_must_be_unique(database_engine) -> None:
    with Session(database_engine) as session:
        session.add(
            Country(
                code="PT",
                name="Portugal",
                alpha3_code="PRT",
            )
        )
        session.commit()

    with Session(database_engine) as session:
        session.add(
            Country(
                code="XX",
                name="Different country",
                alpha3_code="PRT",
            )
        )

        with pytest.raises(IntegrityError):
            session.commit()

        session.rollback()


def test_multiple_countries_can_be_persisted(database_engine) -> None:
    with Session(database_engine) as session:
        session.add_all(
            [
                Country(
                    code="PT",
                    name="Portugal",
                    alpha3_code="PRT",
                ),
                Country(
                    code="ES",
                    name="Spain",
                    alpha3_code="ESP",
                ),
            ]
        )

        session.commit()

    with Session(database_engine) as session:
        assert session.get(Country, "PT") is not None
        assert session.get(Country, "ES") is not None
