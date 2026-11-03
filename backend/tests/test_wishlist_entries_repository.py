"""Integration tests for the global wishlist repository."""

from collections.abc import Generator
from pathlib import Path
from uuid import UUID, uuid4

import pytest
from sqlalchemy import Engine
from sqlalchemy.orm import Session

from app.db.base import Base
from app.db.session import create_database_engine
from app.models.city import City
from app.models.country import Country
from app.models.user import User
from app.repositories.wishlist_entries import WishlistEntryRepository


LISBON_ID = 2267057
MADRID_ID = 3117735


@pytest.fixture
def database_engine(
    tmp_path: Path,
) -> Generator[Engine, None, None]:
    engine = create_database_engine(f"sqlite:///{tmp_path / 'wishlist_repository.db'}")

    Base.metadata.create_all(engine)

    yield engine

    engine.dispose()


def seed_data(session: Session) -> tuple[UUID, UUID]:
    """Seed countries, cities and two independent users."""

    session.add_all(
        [
            Country(
                code="PT",
                name="Portugal",
                alpha3_code="PRT",
                continent="EU",
            ),
            Country(
                code="ES",
                name="Spain",
                alpha3_code="ESP",
                continent="EU",
            ),
        ]
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
                id=MADRID_ID,
                country_code="ES",
                name="Madrid",
                ascii_name="Madrid",
                latitude=40.4165,
                longitude=-3.70256,
                population=3255944,
                feature_code="PPLC",
            ),
        ]
    )

    first_user = User(
        username="wishlist_repository_user",
        display_name="Wishlist Repository User",
        password_hash="test-hash",
    )

    second_user = User(
        username="wishlist_repository_other",
        display_name="Other Wishlist User",
        password_hash="test-hash",
    )

    session.add_all([first_user, second_user])
    session.commit()

    return first_user.id, second_user.id


def test_create_country_entry(database_engine: Engine) -> None:
    with Session(database_engine) as session:
        user_id, _ = seed_data(session)
        repository = WishlistEntryRepository(session)

        entry = repository.create(
            user_id=user_id,
            country_code="PT",
        )

        assert entry.id is not None
        assert entry.country_code == "PT"
        assert entry.city_id is None

        saved = repository.get_for_user(
            entry_id=entry.id,
            user_id=user_id,
        )

        assert saved is not None
        assert saved.id == entry.id


def test_create_city_entry(database_engine: Engine) -> None:
    with Session(database_engine) as session:
        user_id, _ = seed_data(session)
        repository = WishlistEntryRepository(session)

        entry = repository.create(
            user_id=user_id,
            city_id=LISBON_ID,
        )

        assert entry.country_code is None
        assert entry.city_id == LISBON_ID


def test_list_for_user_is_isolated(database_engine: Engine) -> None:
    with Session(database_engine) as session:
        first_user, second_user = seed_data(session)
        repository = WishlistEntryRepository(session)

        repository.create(
            user_id=first_user,
            country_code="PT",
        )

        repository.create(
            user_id=first_user,
            city_id=LISBON_ID,
        )

        repository.create(
            user_id=second_user,
            country_code="ES",
        )

        first_entries = repository.list_for_user(first_user)
        second_entries = repository.list_for_user(second_user)

        assert len(first_entries) == 2
        assert len(second_entries) == 1

        assert all(entry.user_id == first_user for entry in first_entries)

        assert all(entry.user_id == second_user for entry in second_entries)


def test_get_for_user_rejects_other_user(
    database_engine: Engine,
) -> None:
    with Session(database_engine) as session:
        owner, other_user = seed_data(session)
        repository = WishlistEntryRepository(session)

        entry = repository.create(
            user_id=owner,
            country_code="PT",
        )

        assert (
            repository.get_for_user(
                entry_id=entry.id,
                user_id=other_user,
            )
            is None
        )


def test_find_existing_country_entry(
    database_engine: Engine,
) -> None:
    with Session(database_engine) as session:
        user_id, _ = seed_data(session)
        repository = WishlistEntryRepository(session)

        entry = repository.create(
            user_id=user_id,
            country_code="PT",
        )

        existing = repository.get_country_entry(
            user_id=user_id,
            country_code="PT",
        )

        assert existing is not None
        assert existing.id == entry.id

        assert (
            repository.get_country_entry(
                user_id=user_id,
                country_code="ES",
            )
            is None
        )


def test_find_existing_city_entry(
    database_engine: Engine,
) -> None:
    with Session(database_engine) as session:
        user_id, _ = seed_data(session)
        repository = WishlistEntryRepository(session)

        entry = repository.create(
            user_id=user_id,
            city_id=LISBON_ID,
        )

        existing = repository.get_city_entry(
            user_id=user_id,
            city_id=LISBON_ID,
        )

        assert existing is not None
        assert existing.id == entry.id

        assert (
            repository.get_city_entry(
                user_id=user_id,
                city_id=MADRID_ID,
            )
            is None
        )


def test_existing_destination_lookup_is_user_scoped(
    database_engine: Engine,
) -> None:
    with Session(database_engine) as session:
        owner, other_user = seed_data(session)
        repository = WishlistEntryRepository(session)

        repository.create(
            user_id=owner,
            country_code="PT",
        )

        repository.create(
            user_id=owner,
            city_id=LISBON_ID,
        )

        assert (
            repository.get_country_entry(
                user_id=other_user,
                country_code="PT",
            )
            is None
        )

        assert (
            repository.get_city_entry(
                user_id=other_user,
                city_id=LISBON_ID,
            )
            is None
        )


def test_get_catalog_destinations(
    database_engine: Engine,
) -> None:
    with Session(database_engine) as session:
        seed_data(session)
        repository = WishlistEntryRepository(session)

        country = repository.get_country("PT")
        city = repository.get_city(LISBON_ID)

        assert country is not None
        assert country.name == "Portugal"

        assert city is not None
        assert city.country_code == "PT"

        assert repository.get_country("XX") is None
        assert repository.get_city(999999999) is None


def test_delete_owned_entry(database_engine: Engine) -> None:
    with Session(database_engine) as session:
        user_id, _ = seed_data(session)
        repository = WishlistEntryRepository(session)

        entry = repository.create(
            user_id=user_id,
            country_code="PT",
        )

        deleted = repository.delete_for_user(
            entry_id=entry.id,
            user_id=user_id,
        )

        assert deleted is True

        assert (
            repository.get_for_user(
                entry_id=entry.id,
                user_id=user_id,
            )
            is None
        )


def test_delete_rejects_other_user(database_engine: Engine) -> None:
    with Session(database_engine) as session:
        owner, other_user = seed_data(session)
        repository = WishlistEntryRepository(session)

        entry = repository.create(
            user_id=owner,
            country_code="PT",
        )

        deleted = repository.delete_for_user(
            entry_id=entry.id,
            user_id=other_user,
        )

        assert deleted is False

        assert (
            repository.get_for_user(
                entry_id=entry.id,
                user_id=owner,
            )
            is not None
        )


def test_create_without_commit_can_be_rolled_back(
    database_engine: Engine,
) -> None:
    with Session(database_engine) as session:
        user_id, _ = seed_data(session)
        repository = WishlistEntryRepository(session)

        entry = repository.create(
            user_id=user_id,
            country_code="PT",
            commit=False,
        )

        entry_id = entry.id
        session.rollback()

    with Session(database_engine) as session:
        repository = WishlistEntryRepository(session)

        assert (
            repository.get_for_user(
                entry_id=entry_id,
                user_id=user_id,
            )
            is None
        )


def test_delete_without_commit_can_be_rolled_back(
    database_engine: Engine,
) -> None:
    with Session(database_engine) as session:
        user_id, _ = seed_data(session)
        repository = WishlistEntryRepository(session)

        entry = repository.create(
            user_id=user_id,
            country_code="PT",
        )

        entry_id = entry.id

        assert repository.delete_for_user(
            entry_id=entry_id,
            user_id=user_id,
            commit=False,
        )

        session.rollback()

    with Session(database_engine) as session:
        repository = WishlistEntryRepository(session)

        assert (
            repository.get_for_user(
                entry_id=entry_id,
                user_id=user_id,
            )
            is not None
        )


def test_missing_entry_returns_none(database_engine: Engine) -> None:
    with Session(database_engine) as session:
        user_id, _ = seed_data(session)
        repository = WishlistEntryRepository(session)

        assert (
            repository.get_for_user(
                entry_id=uuid4(),
                user_id=user_id,
            )
            is None
        )
