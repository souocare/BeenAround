"""Tests for the historical residence repository."""

from datetime import date
from pathlib import Path

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.base import Base
from app.db.session import create_database_engine
from app.domain.visit_dates import DatePrecision
from app.models.city import City
from app.models.country import Country
from app.models.residence import Residence
from app.models.user import User
from app.repositories.residences import ResidenceRepository


LISBON_ID = 2267057
PORTO_ID = 2735943


@pytest.fixture
def database_engine(tmp_path: Path):
    engine = create_database_engine(f"sqlite:///{tmp_path / 'residences_repository.db'}")

    Base.metadata.create_all(engine)

    yield engine

    engine.dispose()


def seed_data(session: Session) -> tuple[User, User]:
    """Create two users and the geographical test records."""

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

    first_user = User(
        username="first_user",
        display_name="First User",
        password_hash="test-hash-not-a-real-password",
    )

    second_user = User(
        username="second_user",
        display_name="Second User",
        password_hash="test-hash-not-a-real-password",
    )

    session.add_all([first_user, second_user])
    session.commit()

    return first_user, second_user


def create_residence(
    repository: ResidenceRepository,
    user_id,
    *,
    city_id: int | None = LISBON_ID,
    commit: bool = True,
) -> Residence:
    return repository.create(
        user_id=user_id,
        country_code="PT",
        city_id=city_id,
        started_on=date(2020, 1, 1),
        started_on_precision=DatePrecision.MONTH,
        ended_on=date(2023, 12, 1),
        ended_on_precision=DatePrecision.MONTH,
        commit=commit,
    )


def test_create_and_get_residence(database_engine) -> None:
    with Session(database_engine) as session:
        user, _ = seed_data(session)

        repository = ResidenceRepository(session)

        residence = create_residence(repository, user.id)

        saved = repository.get_for_user(
            residence_id=residence.id,
            user_id=user.id,
        )

        assert saved is not None
        assert saved.id == residence.id
        assert saved.country_code == "PT"
        assert saved.city_id == LISBON_ID
        assert saved.started_on_precision == "month"
        assert saved.ended_on_precision == "month"


def test_create_country_residence_without_city(database_engine) -> None:
    with Session(database_engine) as session:
        user, _ = seed_data(session)

        repository = ResidenceRepository(session)

        residence = create_residence(
            repository,
            user.id,
            city_id=None,
        )

        assert residence.city_id is None
        assert residence.country_code == "PT"


def test_list_for_user_is_isolated(database_engine) -> None:
    with Session(database_engine) as session:
        first_user, second_user = seed_data(session)

        repository = ResidenceRepository(session)

        create_residence(repository, first_user.id)
        create_residence(repository, first_user.id, city_id=PORTO_ID)
        create_residence(repository, second_user.id)

        first_residences = repository.list_for_user(first_user.id)
        second_residences = repository.list_for_user(second_user.id)

        assert len(first_residences) == 2
        assert len(second_residences) == 1

        assert all(residence.user_id == first_user.id for residence in first_residences)

        assert all(residence.user_id == second_user.id for residence in second_residences)


def test_get_for_user_rejects_other_user(database_engine) -> None:
    with Session(database_engine) as session:
        owner, other_user = seed_data(session)

        repository = ResidenceRepository(session)

        residence = create_residence(repository, owner.id)

        result = repository.get_for_user(
            residence_id=residence.id,
            user_id=other_user.id,
        )

        assert result is None


def test_repository_can_retrieve_catalog_city(database_engine) -> None:
    with Session(database_engine) as session:
        seed_data(session)

        repository = ResidenceRepository(session)

        city = repository.get_city(LISBON_ID)

        assert city is not None
        assert city.country_code == "PT"
        assert repository.get_city(999999999) is None


def test_update_residence(database_engine) -> None:
    with Session(database_engine) as session:
        user, _ = seed_data(session)

        repository = ResidenceRepository(session)

        residence = create_residence(repository, user.id)

        updated = repository.update(
            residence=residence,
            country_code="PT",
            city_id=PORTO_ID,
            started_on=date(2021, 3, 1),
            started_on_precision=DatePrecision.MONTH,
            ended_on=date(2024, 6, 1),
            ended_on_precision=DatePrecision.MONTH,
        )

        assert updated.id == residence.id
        assert updated.city_id == PORTO_ID
        assert updated.started_on == date(2021, 3, 1)
        assert updated.ended_on == date(2024, 6, 1)


def test_delete_for_user(database_engine) -> None:
    with Session(database_engine) as session:
        user, _ = seed_data(session)

        repository = ResidenceRepository(session)

        residence = create_residence(repository, user.id)
        residence_id = residence.id

        deleted = repository.delete_for_user(
            residence_id=residence_id,
            user_id=user.id,
        )

        assert deleted is True
        assert (
            repository.get_for_user(
                residence_id=residence_id,
                user_id=user.id,
            )
            is None
        )


def test_delete_for_user_rejects_other_user(database_engine) -> None:
    with Session(database_engine) as session:
        owner, other_user = seed_data(session)

        repository = ResidenceRepository(session)

        residence = create_residence(repository, owner.id)

        deleted = repository.delete_for_user(
            residence_id=residence.id,
            user_id=other_user.id,
        )

        assert deleted is False

        assert (
            repository.get_for_user(
                residence_id=residence.id,
                user_id=owner.id,
            )
            is not None
        )


def test_create_without_commit_can_be_rolled_back(database_engine) -> None:
    with Session(database_engine) as session:
        user, _ = seed_data(session)

        repository = ResidenceRepository(session)

        residence = create_residence(
            repository,
            user.id,
            commit=False,
        )

        residence_id = residence.id

        session.rollback()

    with Session(database_engine) as session:
        saved = session.get(Residence, residence_id)

        assert saved is None


def test_update_without_commit_can_be_rolled_back(database_engine) -> None:
    with Session(database_engine) as session:
        user, _ = seed_data(session)

        repository = ResidenceRepository(session)

        residence = create_residence(repository, user.id)
        residence_id = residence.id

        repository.update(
            residence=residence,
            country_code="PT",
            city_id=PORTO_ID,
            started_on=date(2021, 1, 1),
            started_on_precision=DatePrecision.MONTH,
            ended_on=date(2024, 12, 1),
            ended_on_precision=DatePrecision.MONTH,
            commit=False,
        )

        session.rollback()

    with Session(database_engine) as session:
        saved = session.get(Residence, residence_id)

        assert saved is not None
        assert saved.city_id == LISBON_ID
        assert saved.started_on == date(2020, 1, 1)


def test_delete_without_commit_can_be_rolled_back(database_engine) -> None:
    with Session(database_engine) as session:
        user, _ = seed_data(session)

        repository = ResidenceRepository(session)

        residence = create_residence(repository, user.id)
        residence_id = residence.id

        deleted = repository.delete_for_user(
            residence_id=residence_id,
            user_id=user.id,
            commit=False,
        )

        assert deleted is True

        session.rollback()

    with Session(database_engine) as session:
        assert session.get(Residence, residence_id) is not None


def test_residence_repository_does_not_create_visits(database_engine) -> None:
    """Repository creation does not generate Been records."""

    with Session(database_engine) as session:
        user, _ = seed_data(session)

        repository = ResidenceRepository(session)

        create_residence(repository, user.id)

        assert len(repository.list_for_user(user.id)) == 1

        assert session.scalars(
            select(Residence).where(
                Residence.user_id == user.id,
            )
        ).all()


def test_repository_can_retrieve_catalog_country(database_engine) -> None:
    with Session(database_engine) as session:
        seed_data(session)

        repository = ResidenceRepository(session)

        country = repository.get_country("PT")

        assert country is not None
        assert country.name == "Portugal"
        assert repository.get_country("XX") is None
