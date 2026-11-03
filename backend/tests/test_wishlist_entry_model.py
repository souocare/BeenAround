"""Database integrity tests for global wishlist entries."""

from collections.abc import Generator
from pathlib import Path
from uuid import UUID

import pytest
from sqlalchemy import Engine, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db.base import Base
from app.db.session import create_database_engine
from app.models.city import City
from app.models.country import Country
from app.models.user import User
from app.models.wishlist_entry import WishlistEntry


LISBON_ID = 2267057
MADRID_ID = 3117735


@pytest.fixture
def database_engine(
    tmp_path: Path,
) -> Generator[Engine, None, None]:
    """Create an isolated SQLite database with foreign keys enabled."""

    engine = create_database_engine(f"sqlite:///{tmp_path / 'wishlist_model.db'}")

    Base.metadata.create_all(engine)

    yield engine

    engine.dispose()


def seed_data(session: Session) -> tuple[UUID, UUID]:
    """Create geographical catalog entries and two users."""

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
        username="wishlist_user",
        display_name="Wishlist User",
        password_hash="test-hash",
    )

    second_user = User(
        username="another_wishlist_user",
        display_name="Another Wishlist User",
        password_hash="test-hash",
    )

    session.add_all([first_user, second_user])
    session.commit()

    return first_user.id, second_user.id


def test_create_country_wishlist_entry(database_engine: Engine) -> None:
    """A wishlist entry may reference a country only."""

    with Session(database_engine) as session:
        user_id, _ = seed_data(session)

        entry = WishlistEntry(
            user_id=user_id,
            country_code="PT",
            city_id=None,
        )

        session.add(entry)
        session.commit()

        assert entry.id is not None
        assert entry.country_code == "PT"
        assert entry.city_id is None
        assert entry.created_at is not None


def test_create_city_wishlist_entry(database_engine: Engine) -> None:
    """A wishlist entry may reference a city only."""

    with Session(database_engine) as session:
        user_id, _ = seed_data(session)

        entry = WishlistEntry(
            user_id=user_id,
            country_code=None,
            city_id=LISBON_ID,
        )

        session.add(entry)
        session.commit()

        assert entry.id is not None
        assert entry.country_code is None
        assert entry.city_id == LISBON_ID


def test_country_and_city_entries_can_coexist(
    database_engine: Engine,
) -> None:
    """A city and its country are independent wishlist destinations."""

    with Session(database_engine) as session:
        user_id, _ = seed_data(session)

        session.add_all(
            [
                WishlistEntry(
                    user_id=user_id,
                    country_code="PT",
                ),
                WishlistEntry(
                    user_id=user_id,
                    city_id=LISBON_ID,
                ),
            ]
        )

        session.commit()

        entries = session.scalars(
            select(WishlistEntry).where(WishlistEntry.user_id == user_id)
        ).all()

        assert len(entries) == 2


def test_entry_requires_exactly_one_destination(
    database_engine: Engine,
) -> None:
    """Country and city cannot both be null."""

    with Session(database_engine) as session:
        user_id, _ = seed_data(session)

        session.add(
            WishlistEntry(
                user_id=user_id,
                country_code=None,
                city_id=None,
            )
        )

        with pytest.raises(IntegrityError):
            session.commit()


def test_entry_rejects_two_destinations(
    database_engine: Engine,
) -> None:
    """Country and city cannot both be populated."""

    with Session(database_engine) as session:
        user_id, _ = seed_data(session)

        session.add(
            WishlistEntry(
                user_id=user_id,
                country_code="PT",
                city_id=LISBON_ID,
            )
        )

        with pytest.raises(IntegrityError):
            session.commit()


def test_duplicate_country_is_rejected(
    database_engine: Engine,
) -> None:
    """A user cannot wishlist the same country twice."""

    with Session(database_engine) as session:
        user_id, _ = seed_data(session)

        session.add(
            WishlistEntry(
                user_id=user_id,
                country_code="PT",
            )
        )
        session.commit()

        session.add(
            WishlistEntry(
                user_id=user_id,
                country_code="PT",
            )
        )

        with pytest.raises(IntegrityError):
            session.commit()


def test_duplicate_city_is_rejected(
    database_engine: Engine,
) -> None:
    """A user cannot wishlist the same city twice."""

    with Session(database_engine) as session:
        user_id, _ = seed_data(session)

        session.add(
            WishlistEntry(
                user_id=user_id,
                city_id=LISBON_ID,
            )
        )
        session.commit()

        session.add(
            WishlistEntry(
                user_id=user_id,
                city_id=LISBON_ID,
            )
        )

        with pytest.raises(IntegrityError):
            session.commit()


def test_different_users_can_wishlist_same_country(
    database_engine: Engine,
) -> None:
    """Wishlist uniqueness is scoped to each user."""

    with Session(database_engine) as session:
        first_user_id, second_user_id = seed_data(session)

        session.add_all(
            [
                WishlistEntry(
                    user_id=first_user_id,
                    country_code="PT",
                ),
                WishlistEntry(
                    user_id=second_user_id,
                    country_code="PT",
                ),
            ]
        )

        session.commit()

        entries = session.scalars(select(WishlistEntry)).all()

        assert len(entries) == 2


def test_different_users_can_wishlist_same_city(
    database_engine: Engine,
) -> None:
    """Different users may wishlist the same geographical city."""

    with Session(database_engine) as session:
        first_user_id, second_user_id = seed_data(session)

        session.add_all(
            [
                WishlistEntry(
                    user_id=first_user_id,
                    city_id=LISBON_ID,
                ),
                WishlistEntry(
                    user_id=second_user_id,
                    city_id=LISBON_ID,
                ),
            ]
        )

        session.commit()

        assert len(session.scalars(select(WishlistEntry)).all()) == 2


def test_unknown_country_is_rejected(
    database_engine: Engine,
) -> None:
    """Wishlist countries must exist in the shared catalog."""

    with Session(database_engine) as session:
        user_id, _ = seed_data(session)

        session.add(
            WishlistEntry(
                user_id=user_id,
                country_code="XX",
            )
        )

        with pytest.raises(IntegrityError):
            session.commit()


def test_unknown_city_is_rejected(
    database_engine: Engine,
) -> None:
    """Wishlist cities must exist in the shared catalog."""

    with Session(database_engine) as session:
        user_id, _ = seed_data(session)

        session.add(
            WishlistEntry(
                user_id=user_id,
                city_id=999999999,
            )
        )

        with pytest.raises(IntegrityError):
            session.commit()


def test_deleting_user_removes_wishlist_entries(
    database_engine: Engine,
) -> None:
    """Wishlist entries are deleted when their owner is removed."""

    with Session(database_engine) as session:
        user_id, _ = seed_data(session)

        entry = WishlistEntry(
            user_id=user_id,
            country_code="PT",
        )

        session.add(entry)
        session.commit()

        entry_id = entry.id

        user = session.get(User, user_id)

        session.delete(user)
        session.commit()

        assert session.get(WishlistEntry, entry_id) is None


def test_multiple_destinations_are_supported(
    database_engine: Engine,
) -> None:
    """A user may have multiple country and city wishlist entries."""

    with Session(database_engine) as session:
        user_id, _ = seed_data(session)

        session.add_all(
            [
                WishlistEntry(
                    user_id=user_id,
                    country_code="PT",
                ),
                WishlistEntry(
                    user_id=user_id,
                    country_code="ES",
                ),
                WishlistEntry(
                    user_id=user_id,
                    city_id=LISBON_ID,
                ),
                WishlistEntry(
                    user_id=user_id,
                    city_id=MADRID_ID,
                ),
            ]
        )

        session.commit()

        entries = session.scalars(
            select(WishlistEntry).where(WishlistEntry.user_id == user_id)
        ).all()

        assert len(entries) == 4
