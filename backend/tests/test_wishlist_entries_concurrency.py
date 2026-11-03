"""SQLite concurrency tests for global wishlist operations."""

from collections.abc import Generator
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from threading import Event
from uuid import UUID

import pytest
from sqlalchemy import Engine, select
from sqlalchemy.orm import Session

from app.db.base import Base
from app.db.session import create_database_engine
from app.db.write_transactions import sqlite_write_session
from app.models.city import City
from app.models.country import Country
from app.models.user import User
from app.models.wishlist_entry import WishlistEntry
from app.repositories.wishlist_entries import WishlistEntryRepository
from app.schemas.wishlist_entries import WishlistEntryCreate
from app.services.wishlist_entries import add_wishlist_entries


LISBON_ID = 2267057


@pytest.fixture
def database_engine(
    tmp_path: Path,
) -> Generator[Engine, None, None]:
    """Provide a file-backed SQLite database."""

    engine = create_database_engine(f"sqlite:///{tmp_path / 'wishlist_concurrency.db'}")

    Base.metadata.create_all(engine)

    yield engine

    engine.dispose()


@pytest.fixture
def user_ids(database_engine: Engine) -> tuple[UUID, UUID]:
    """Seed geographical data and two users."""

    with Session(database_engine) as session:
        session.add(
            Country(
                code="PT",
                name="Portugal",
                alpha3_code="PRT",
                continent="EU",
            )
        )

        session.flush()

        session.add(
            City(
                id=LISBON_ID,
                country_code="PT",
                name="Lisbon",
                ascii_name="Lisbon",
                latitude=38.71667,
                longitude=-9.13333,
                population=517802,
                feature_code="PPLC",
            )
        )

        first = User(
            username="wishlist_concurrent_first",
            display_name="First User",
            password_hash="test-hash",
        )

        second = User(
            username="wishlist_concurrent_second",
            display_name="Second User",
            password_hash="test-hash",
        )

        session.add_all([first, second])
        session.commit()

        return first.id, second.id


def list_entries(
    engine: Engine,
    *,
    user_id: UUID | None = None,
) -> list[WishlistEntry]:
    """Read persisted wishlist entries using a separate session."""

    with Session(engine) as session:
        statement = select(WishlistEntry)

        if user_id is not None:
            statement = statement.where(WishlistEntry.user_id == user_id)

        return list(session.scalars(statement).all())


def test_concurrent_country_creation_is_idempotent(
    database_engine: Engine,
    user_ids: tuple[UUID, UUID],
) -> None:
    """Two competing writers must not create duplicate country entries."""

    user_id, _ = user_ids

    first_write_ready = Event()
    allow_first_commit = Event()

    def first_writer() -> None:
        with sqlite_write_session(database_engine) as session:
            repository = WishlistEntryRepository(session)

            repository.create(
                user_id=user_id,
                country_code="PT",
                commit=False,
            )

            first_write_ready.set()

            assert allow_first_commit.wait(timeout=10)

    def second_writer():
        assert first_write_ready.wait(timeout=10)

        return add_wishlist_entries(
            engine=database_engine,
            user_id=user_id,
            payload=WishlistEntryCreate(country_code="PT"),
        )

    with ThreadPoolExecutor(max_workers=2) as executor:
        first_future = executor.submit(first_writer)

        assert first_write_ready.wait(timeout=10)

        second_future = executor.submit(second_writer)

        # Release the first transaction, allowing the second writer
        # to acquire the SQLite write lock and recheck current state.
        allow_first_commit.set()

        first_future.result(timeout=10)
        result = second_future.result(timeout=10)

    assert result.created == []
    assert len(result.existing) == 1

    entries = list_entries(
        database_engine,
        user_id=user_id,
    )

    assert len(entries) == 1
    assert entries[0].country_code == "PT"
    assert result.existing[0].id == entries[0].id


def test_concurrent_city_and_country_creation_is_idempotent(
    database_engine: Engine,
    user_ids: tuple[UUID, UUID],
) -> None:
    """A competing combined request must not create duplicate entries."""

    user_id, _ = user_ids

    first_write_ready = Event()
    allow_first_commit = Event()

    def first_writer() -> None:
        with sqlite_write_session(database_engine) as session:
            repository = WishlistEntryRepository(session)

            repository.create(
                user_id=user_id,
                city_id=LISBON_ID,
                commit=False,
            )

            repository.create(
                user_id=user_id,
                country_code="PT",
                commit=False,
            )

            first_write_ready.set()

            assert allow_first_commit.wait(timeout=10)

    def second_writer():
        assert first_write_ready.wait(timeout=10)

        return add_wishlist_entries(
            engine=database_engine,
            user_id=user_id,
            payload=WishlistEntryCreate(
                city_id=LISBON_ID,
                include_country=True,
            ),
        )

    with ThreadPoolExecutor(max_workers=2) as executor:
        first_future = executor.submit(first_writer)

        assert first_write_ready.wait(timeout=10)

        second_future = executor.submit(second_writer)

        allow_first_commit.set()

        first_future.result(timeout=10)
        result = second_future.result(timeout=10)

    assert result.created == []
    assert len(result.existing) == 2

    entries = list_entries(
        database_engine,
        user_id=user_id,
    )

    assert len(entries) == 2

    assert {(entry.country_code, entry.city_id) for entry in entries} == {
        ("PT", None),
        (None, LISBON_ID),
    }


def test_concurrent_writes_are_isolated_between_users(
    database_engine: Engine,
    user_ids: tuple[UUID, UUID],
) -> None:
    """Different users may add the same country concurrently."""

    first_user, second_user = user_ids

    start = Event()

    def add_country(user_id: UUID):
        assert start.wait(timeout=10)

        return add_wishlist_entries(
            engine=database_engine,
            user_id=user_id,
            payload=WishlistEntryCreate(country_code="PT"),
        )

    with ThreadPoolExecutor(max_workers=2) as executor:
        first_future = executor.submit(
            add_country,
            first_user,
        )

        second_future = executor.submit(
            add_country,
            second_user,
        )

        start.set()

        first_result = first_future.result(timeout=10)
        second_result = second_future.result(timeout=10)

    assert len(first_result.created) == 1
    assert len(second_result.created) == 1

    first_entries = list_entries(
        database_engine,
        user_id=first_user,
    )

    second_entries = list_entries(
        database_engine,
        user_id=second_user,
    )

    assert len(first_entries) == 1
    assert len(second_entries) == 1

    assert first_entries[0].id != second_entries[0].id
    assert first_entries[0].country_code == "PT"
    assert second_entries[0].country_code == "PT"
