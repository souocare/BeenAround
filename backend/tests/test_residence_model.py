"""Tests for the historical residence persistence model."""

from datetime import date
from pathlib import Path
from uuid import UUID, uuid4

import pytest
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db.base import Base
from app.db.session import create_database_engine
from app.models.city import City
from app.models.city_visit import CityVisit
from app.models.country import Country
from app.models.country_visit import CountryVisit
from app.models.residence import Residence
from app.models.user import User


LISBON_ID = 2267057
PORTO_ID = 2735943


@pytest.fixture
def database_engine(tmp_path: Path):
    """Create an isolated SQLite database for each test."""

    engine = create_database_engine(f"sqlite:///{tmp_path / 'residences.db'}")

    Base.metadata.create_all(engine)

    yield engine

    engine.dispose()


def make_user(username: str) -> User:
    return User(
        username=username,
        display_name=username,
        password_hash="test-hash-not-a-real-password",
    )


def seed_geography(session: Session) -> None:
    """Create the geographic records required by residence tests."""

    session.add(
        Country(
            code="PT",
            name="Portugal",
            alpha3_code="PRT",
            continent="Europe",
        )
    )

    session.flush()

    session.add_all(
        [
            City(
                id=LISBON_ID,
                country_code="PT",
                name="Lisbon",
                ascii_name="Lisbon",
                latitude=38.71667,
                longitude=-9.13333,
                population=517802,
                feature_code="PPLC",
            ),
            City(
                id=PORTO_ID,
                country_code="PT",
                name="Porto",
                ascii_name="Porto",
                latitude=41.14961,
                longitude=-8.61099,
                population=249633,
                feature_code="PPLA",
            ),
        ]
    )

    session.commit()


def make_residence(
    user_id: UUID,
    *,
    country_code: str = "PT",
    city_id: int | None = LISBON_ID,
    started_on: date | None = date(2020, 1, 1),
    started_on_precision: str | None = "month",
    ended_on: date | None = date(2023, 12, 1),
    ended_on_precision: str | None = "month",
) -> Residence:
    """Create a residence with configurable dates and destination."""

    return Residence(
        user_id=user_id,
        country_code=country_code,
        city_id=city_id,
        started_on=started_on,
        started_on_precision=started_on_precision,
        ended_on=ended_on,
        ended_on_precision=ended_on_precision,
    )


def test_country_residence_can_be_persisted(database_engine) -> None:
    """A residence may reference a country without specifying a city."""

    with Session(database_engine) as session:
        seed_geography(session)

        user = make_user("country_resident")
        session.add(user)
        session.flush()

        residence = make_residence(
            user.id,
            city_id=None,
        )

        session.add(residence)
        session.commit()

        residence_id = residence.id

    with Session(database_engine) as session:
        saved = session.get(Residence, residence_id)

        assert saved is not None
        assert saved.country_code == "PT"
        assert saved.city_id is None
        assert saved.started_on == date(2020, 1, 1)
        assert saved.started_on_precision == "month"
        assert saved.ended_on == date(2023, 12, 1)
        assert saved.ended_on_precision == "month"
        assert saved.created_at is not None
        assert saved.updated_at is not None


def test_city_residence_can_be_persisted(database_engine) -> None:
    """A residence may reference a city in its geographical country."""

    with Session(database_engine) as session:
        seed_geography(session)

        user = make_user("city_resident")
        session.add(user)
        session.flush()

        residence = make_residence(
            user.id,
            city_id=LISBON_ID,
        )

        session.add(residence)
        session.commit()

        residence_id = residence.id

    with Session(database_engine) as session:
        saved = session.get(Residence, residence_id)

        assert saved is not None
        assert saved.country_code == "PT"
        assert saved.city_id == LISBON_ID


def test_residence_accepts_day_precision(database_engine) -> None:
    """Exact start and end dates are valid for a residence."""

    with Session(database_engine) as session:
        seed_geography(session)

        user = make_user("day_precision")
        session.add(user)
        session.flush()

        residence = make_residence(
            user.id,
            started_on=date(2020, 1, 15),
            started_on_precision="day",
            ended_on=date(2023, 12, 20),
            ended_on_precision="day",
        )

        session.add(residence)
        session.commit()

        assert residence.id is not None


def test_residence_accepts_mixed_day_and_month_precision(
    database_engine,
) -> None:
    """Start and end boundaries may have different valid precisions."""

    with Session(database_engine) as session:
        seed_geography(session)

        user = make_user("mixed_precision")
        session.add(user)
        session.flush()

        session.add(
            make_residence(
                user.id,
                started_on=date(2020, 1, 15),
                started_on_precision="day",
                ended_on=date(2023, 12, 1),
                ended_on_precision="month",
            )
        )

        session.commit()


@pytest.mark.parametrize(
    ("started_on_precision", "ended_on_precision"),
    [
        ("year", "month"),
        ("month", "year"),
        ("year", "year"),
        ("invalid", "month"),
        ("month", "invalid"),
    ],
)
def test_residence_rejects_unsupported_precision(
    database_engine,
    started_on_precision,
    ended_on_precision,
) -> None:
    """Residences require at least month-level precision."""

    with Session(database_engine) as session:
        seed_geography(session)

        user = make_user("invalid_precision")
        session.add(user)
        session.flush()

        session.add(
            make_residence(
                user.id,
                started_on_precision=started_on_precision,
                ended_on_precision=ended_on_precision,
            )
        )

        with pytest.raises(IntegrityError):
            session.flush()

        session.rollback()


@pytest.mark.parametrize(
    ("started_on", "started_on_precision", "ended_on", "ended_on_precision"),
    [
        (None, None, date(2023, 12, 1), "month"),
        (date(2020, 1, 1), "month", None, None),
        (None, None, None, None),
        (date(2020, 1, 1), None, date(2023, 12, 1), "month"),
        (date(2020, 1, 1), "month", date(2023, 12, 1), None),
    ],
)
def test_residence_requires_complete_dates(
    database_engine,
    started_on,
    started_on_precision,
    ended_on,
    ended_on_precision,
) -> None:
    """Both residence boundaries and their precisions are mandatory."""

    with Session(database_engine) as session:
        seed_geography(session)

        user = make_user("missing_dates")
        session.add(user)
        session.flush()

        session.add(
            make_residence(
                user.id,
                started_on=started_on,
                started_on_precision=started_on_precision,
                ended_on=ended_on,
                ended_on_precision=ended_on_precision,
            )
        )

        with pytest.raises(IntegrityError):
            session.flush()

        session.rollback()


@pytest.mark.parametrize(
    ("started_on", "started_on_precision", "ended_on", "ended_on_precision"),
    [
        (
            date(2020, 1, 15),
            "month",
            date(2023, 12, 1),
            "month",
        ),
        (
            date(2020, 1, 1),
            "month",
            date(2023, 12, 20),
            "month",
        ),
    ],
)
def test_residence_rejects_noncanonical_month_dates(
    database_engine,
    started_on,
    started_on_precision,
    ended_on,
    ended_on_precision,
) -> None:
    """Monthly dates must use the first day as canonical storage."""

    with Session(database_engine) as session:
        seed_geography(session)

        user = make_user("noncanonical_dates")
        session.add(user)
        session.flush()

        session.add(
            make_residence(
                user.id,
                started_on=started_on,
                started_on_precision=started_on_precision,
                ended_on=ended_on,
                ended_on_precision=ended_on_precision,
            )
        )

        with pytest.raises(IntegrityError):
            session.flush()

        session.rollback()


@pytest.mark.parametrize(
    ("started_on", "started_on_precision", "ended_on", "ended_on_precision"),
    [
        (
            date(2024, 6, 1),
            "month",
            date(2024, 5, 1),
            "month",
        ),
        (
            date(2024, 6, 15),
            "day",
            date(2024, 6, 10),
            "day",
        ),
        (
            date(2024, 7, 1),
            "month",
            date(2024, 6, 30),
            "day",
        ),
    ],
)
def test_residence_rejects_invalid_date_ranges(
    database_engine,
    started_on,
    started_on_precision,
    ended_on,
    ended_on_precision,
) -> None:
    """A residence cannot end before it could have started."""

    with Session(database_engine) as session:
        seed_geography(session)

        user = make_user("invalid_range")
        session.add(user)
        session.flush()

        session.add(
            make_residence(
                user.id,
                started_on=started_on,
                started_on_precision=started_on_precision,
                ended_on=ended_on,
                ended_on_precision=ended_on_precision,
            )
        )

        with pytest.raises(IntegrityError):
            session.flush()

        session.rollback()


def test_residence_accepts_possible_same_month_range(
    database_engine,
) -> None:
    """Partial-date boundaries may refer to days within the same month."""

    with Session(database_engine) as session:
        seed_geography(session)

        user = make_user("same_month")
        session.add(user)
        session.flush()

        session.add(
            make_residence(
                user.id,
                started_on=date(2024, 6, 20),
                started_on_precision="day",
                ended_on=date(2024, 6, 1),
                ended_on_precision="month",
            )
        )

        session.commit()


@pytest.mark.parametrize(
    ("country_code", "city_id"),
    [
        ("XX", None),
        ("PT", 999999999),
    ],
)
def test_residence_requires_existing_destination(
    database_engine,
    country_code,
    city_id,
) -> None:
    """Foreign keys must reference existing geographical records."""

    with Session(database_engine) as session:
        seed_geography(session)

        user = make_user("invalid_destination")
        session.add(user)
        session.flush()

        session.add(
            make_residence(
                user.id,
                country_code=country_code,
                city_id=city_id,
            )
        )

        with pytest.raises(IntegrityError):
            session.flush()

        session.rollback()


def test_residence_requires_existing_user(database_engine) -> None:
    """A residence cannot reference a user that does not exist."""

    with Session(database_engine) as session:
        seed_geography(session)

        session.add(
            make_residence(
                uuid4(),
            )
        )

        with pytest.raises(IntegrityError):
            session.flush()

        session.rollback()


def test_multiple_residences_in_same_city_are_allowed(
    database_engine,
) -> None:
    """A user may have lived in the same city during separate periods."""

    with Session(database_engine) as session:
        seed_geography(session)

        user = make_user("multiple_residences")
        session.add(user)
        session.flush()

        session.add_all(
            [
                make_residence(
                    user.id,
                    started_on=date(2018, 1, 1),
                    ended_on=date(2020, 12, 1),
                ),
                make_residence(
                    user.id,
                    started_on=date(2022, 1, 1),
                    ended_on=date(2024, 12, 1),
                ),
            ]
        )

        session.commit()

        residences = session.scalars(
            select(Residence).where(
                Residence.user_id == user.id,
                Residence.city_id == LISBON_ID,
            )
        ).all()

        assert len(residences) == 2


def test_overlapping_residences_are_allowed_by_database(
    database_engine,
) -> None:
    """Overlap confirmation belongs to application logic, not SQL constraints."""

    with Session(database_engine) as session:
        seed_geography(session)

        user = make_user("overlapping_residences")
        session.add(user)
        session.flush()

        session.add_all(
            [
                make_residence(
                    user.id,
                    city_id=LISBON_ID,
                    started_on=date(2020, 1, 1),
                    ended_on=date(2023, 12, 1),
                ),
                make_residence(
                    user.id,
                    city_id=PORTO_ID,
                    started_on=date(2022, 9, 1),
                    ended_on=date(2024, 6, 1),
                ),
            ]
        )

        session.commit()

        residences = session.scalars(
            select(Residence).where(
                Residence.user_id == user.id,
            )
        ).all()

        assert len(residences) == 2


def test_deleting_user_cascades_to_residences(database_engine) -> None:
    """Deleting a user must also remove their historical residences."""

    with Session(database_engine) as session:
        seed_geography(session)

        user = make_user("deleted_resident")
        session.add(user)
        session.flush()

        user_id = user.id

        residence = make_residence(user_id)

        session.add(residence)
        session.commit()

        residence_id = residence.id

        session.delete(user)
        session.commit()

        assert session.get(Residence, residence_id) is None


def test_residence_does_not_create_visits(database_engine) -> None:
    """Persisting a residence must not create country or city visits."""

    with Session(database_engine) as session:
        seed_geography(session)

        user = make_user("independent_residence")
        session.add(user)
        session.flush()

        session.add(make_residence(user.id))
        session.commit()

        city_visits = session.scalars(select(CityVisit).where(CityVisit.user_id == user.id)).all()

        country_visits = session.scalars(
            select(CountryVisit).where(CountryVisit.user_id == user.id)
        ).all()

        assert city_visits == []
        assert country_visits == []
