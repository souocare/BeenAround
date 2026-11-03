"""Integration tests for global wishlist application services."""

from collections.abc import Generator
from pathlib import Path
from unittest.mock import patch
from uuid import UUID, uuid4

import pytest
from sqlalchemy import Engine, select
from sqlalchemy.orm import Session

from app.db.base import Base
from app.db.session import create_database_engine
from app.models.city import City
from app.models.country import Country
from app.models.user import User
from app.models.wishlist_entry import WishlistEntry
from app.repositories.wishlist_entries import WishlistEntryRepository
from app.schemas.wishlist_entries import WishlistEntryCreate
from app.services.wishlist_entries import (
    WishlistDestinationNotFound,
    WishlistEntryNotFound,
    add_wishlist_entries,
    delete_wishlist_entry,
)


LISBON_ID = 2267057
MADRID_ID = 3117735


@pytest.fixture
def database_engine(
    tmp_path: Path,
) -> Generator[Engine, None, None]:
    engine = create_database_engine(f"sqlite:///{tmp_path / 'wishlist_service.db'}")

    Base.metadata.create_all(engine)

    yield engine

    engine.dispose()


@pytest.fixture
def user_ids(database_engine: Engine) -> tuple[UUID, UUID]:
    with Session(database_engine) as session:
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

        first = User(
            username="wishlist_service_first",
            display_name="First User",
            password_hash="test-hash",
        )

        second = User(
            username="wishlist_service_second",
            display_name="Second User",
            password_hash="test-hash",
        )

        session.add_all([first, second])
        session.commit()

        return first.id, second.id


def country_payload(code: str = "PT") -> WishlistEntryCreate:
    return WishlistEntryCreate(country_code=code)


def city_payload(
    city_id: int = LISBON_ID,
    *,
    include_country: bool = False,
) -> WishlistEntryCreate:
    return WishlistEntryCreate(
        city_id=city_id,
        include_country=include_country,
    )


def list_entries(
    engine: Engine,
    user_id: UUID,
) -> list[WishlistEntry]:
    with Session(engine) as session:
        statement = select(WishlistEntry).where(WishlistEntry.user_id == user_id)

        return list(session.scalars(statement).all())


def test_add_country(
    database_engine: Engine,
    user_ids: tuple[UUID, UUID],
) -> None:
    user_id, _ = user_ids

    result = add_wishlist_entries(
        engine=database_engine,
        user_id=user_id,
        payload=country_payload(),
    )

    assert len(result.created) == 1
    assert result.existing == []
    assert result.created[0].country_code == "PT"
    assert result.created[0].city_id is None

    assert result.created[0].created_at is not None
    assert result.created[0].updated_at is not None


def test_add_city_without_country(
    database_engine: Engine,
    user_ids: tuple[UUID, UUID],
) -> None:
    user_id, _ = user_ids

    result = add_wishlist_entries(
        engine=database_engine,
        user_id=user_id,
        payload=city_payload(),
    )

    assert len(result.created) == 1
    assert result.created[0].city_id == LISBON_ID

    entries = list_entries(database_engine, user_id)

    assert len(entries) == 1
    assert entries[0].country_code is None


def test_add_city_and_country(
    database_engine: Engine,
    user_ids: tuple[UUID, UUID],
) -> None:
    user_id, _ = user_ids

    result = add_wishlist_entries(
        engine=database_engine,
        user_id=user_id,
        payload=city_payload(include_country=True),
    )

    assert len(result.created) == 2
    assert result.existing == []

    entries = list_entries(database_engine, user_id)

    assert len(entries) == 2

    assert {entry.city_id for entry in entries if entry.city_id is not None} == {LISBON_ID}

    assert {entry.country_code for entry in entries if entry.country_code is not None} == {"PT"}


def test_existing_country_is_not_duplicated(
    database_engine: Engine,
    user_ids: tuple[UUID, UUID],
) -> None:
    user_id, _ = user_ids

    first = add_wishlist_entries(
        engine=database_engine,
        user_id=user_id,
        payload=country_payload(),
    )

    second = add_wishlist_entries(
        engine=database_engine,
        user_id=user_id,
        payload=country_payload(),
    )

    assert len(first.created) == 1
    assert second.created == []
    assert len(second.existing) == 1

    assert first.created[0].id == second.existing[0].id
    assert len(list_entries(database_engine, user_id)) == 1


def test_existing_city_is_not_duplicated(
    database_engine: Engine,
    user_ids: tuple[UUID, UUID],
) -> None:
    user_id, _ = user_ids

    add_wishlist_entries(
        engine=database_engine,
        user_id=user_id,
        payload=city_payload(),
    )

    result = add_wishlist_entries(
        engine=database_engine,
        user_id=user_id,
        payload=city_payload(),
    )

    assert result.created == []
    assert len(result.existing) == 1
    assert len(list_entries(database_engine, user_id)) == 1


def test_existing_country_only_creates_city(
    database_engine: Engine,
    user_ids: tuple[UUID, UUID],
) -> None:
    user_id, _ = user_ids

    add_wishlist_entries(
        engine=database_engine,
        user_id=user_id,
        payload=country_payload(),
    )

    result = add_wishlist_entries(
        engine=database_engine,
        user_id=user_id,
        payload=city_payload(include_country=True),
    )

    assert len(result.created) == 1
    assert result.created[0].city_id == LISBON_ID

    assert len(result.existing) == 1
    assert result.existing[0].country_code == "PT"


def test_existing_city_only_creates_country(
    database_engine: Engine,
    user_ids: tuple[UUID, UUID],
) -> None:
    user_id, _ = user_ids

    add_wishlist_entries(
        engine=database_engine,
        user_id=user_id,
        payload=city_payload(),
    )

    result = add_wishlist_entries(
        engine=database_engine,
        user_id=user_id,
        payload=city_payload(include_country=True),
    )

    assert len(result.created) == 1
    assert result.created[0].country_code == "PT"

    assert len(result.existing) == 1
    assert result.existing[0].city_id == LISBON_ID


def test_both_destinations_existing(
    database_engine: Engine,
    user_ids: tuple[UUID, UUID],
) -> None:
    user_id, _ = user_ids

    first = add_wishlist_entries(
        engine=database_engine,
        user_id=user_id,
        payload=city_payload(include_country=True),
    )

    second = add_wishlist_entries(
        engine=database_engine,
        user_id=user_id,
        payload=city_payload(include_country=True),
    )

    assert len(first.created) == 2
    assert second.created == []
    assert len(second.existing) == 2
    assert len(list_entries(database_engine, user_id)) == 2


def test_unknown_country_is_rejected(
    database_engine: Engine,
    user_ids: tuple[UUID, UUID],
) -> None:
    user_id, _ = user_ids

    with pytest.raises(
        WishlistDestinationNotFound,
        match="Country not found",
    ):
        add_wishlist_entries(
            engine=database_engine,
            user_id=user_id,
            payload=country_payload("XX"),
        )

    assert list_entries(database_engine, user_id) == []


def test_unknown_city_is_rejected(
    database_engine: Engine,
    user_ids: tuple[UUID, UUID],
) -> None:
    user_id, _ = user_ids

    with pytest.raises(
        WishlistDestinationNotFound,
        match="City not found",
    ):
        add_wishlist_entries(
            engine=database_engine,
            user_id=user_id,
            payload=city_payload(999999999),
        )

    assert list_entries(database_engine, user_id) == []


def test_atomic_rollback_if_second_create_fails(
    database_engine: Engine,
    user_ids: tuple[UUID, UUID],
) -> None:
    """No city remains persisted if the country insert fails."""

    user_id, _ = user_ids

    original_create = WishlistEntryRepository.create

    calls = 0

    def failing_create(self, **kwargs):
        nonlocal calls

        calls += 1

        if calls == 2:
            raise RuntimeError("Simulated country insertion failure")

        return original_create(self, **kwargs)

    with patch.object(
        WishlistEntryRepository,
        "create",
        failing_create,
    ):
        with pytest.raises(
            RuntimeError,
            match="Simulated country insertion failure",
        ):
            add_wishlist_entries(
                engine=database_engine,
                user_id=user_id,
                payload=city_payload(include_country=True),
            )

    assert list_entries(database_engine, user_id) == []


def test_users_have_independent_wishlists(
    database_engine: Engine,
    user_ids: tuple[UUID, UUID],
) -> None:
    first_user, second_user = user_ids

    add_wishlist_entries(
        engine=database_engine,
        user_id=first_user,
        payload=country_payload(),
    )

    add_wishlist_entries(
        engine=database_engine,
        user_id=second_user,
        payload=country_payload(),
    )

    first_entries = list_entries(database_engine, first_user)
    second_entries = list_entries(database_engine, second_user)

    assert len(first_entries) == 1
    assert len(second_entries) == 1

    assert first_entries[0].id != second_entries[0].id


def test_delete_entry(
    database_engine: Engine,
    user_ids: tuple[UUID, UUID],
) -> None:
    user_id, _ = user_ids

    created = add_wishlist_entries(
        engine=database_engine,
        user_id=user_id,
        payload=country_payload(),
    )

    entry_id = created.created[0].id

    delete_wishlist_entry(
        engine=database_engine,
        user_id=user_id,
        entry_id=entry_id,
    )

    assert list_entries(database_engine, user_id) == []


def test_delete_rejects_other_user(
    database_engine: Engine,
    user_ids: tuple[UUID, UUID],
) -> None:
    owner, other_user = user_ids

    created = add_wishlist_entries(
        engine=database_engine,
        user_id=owner,
        payload=country_payload(),
    )

    entry_id = created.created[0].id

    with pytest.raises(WishlistEntryNotFound):
        delete_wishlist_entry(
            engine=database_engine,
            user_id=other_user,
            entry_id=entry_id,
        )

    assert len(list_entries(database_engine, owner)) == 1


def test_delete_missing_entry(
    database_engine: Engine,
    user_ids: tuple[UUID, UUID],
) -> None:
    user_id, _ = user_ids

    with pytest.raises(WishlistEntryNotFound):
        delete_wishlist_entry(
            engine=database_engine,
            user_id=user_id,
            entry_id=uuid4(),
        )
