"""Tests for user-scoped flight persistence."""

from collections.abc import Generator
from datetime import date
from uuid import UUID, uuid4

import pytest
from sqlalchemy import Engine, create_engine, event
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.models.airline import Airline  # noqa: F401
from app.models.airport import Airport
from app.models.country import Country  # noqa: F401
from app.models.flight import Flight  # noqa: F401
from app.models.user import User
from app.repositories.flights import FlightRepository


@pytest.fixture
def session() -> Generator[Session, None, None]:
    """Create an isolated SQLite session with foreign keys enabled."""

    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )

    @event.listens_for(engine, "connect")
    def enable_foreign_keys(dbapi_connection, connection_record) -> None:
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    Base.metadata.create_all(engine)

    try:
        with Session(engine) as db:
            yield db
    finally:
        engine.dispose()


def flight_values(
    *,
    departure_on: date = date(2025, 9, 10),
    status: str = "flown",
) -> dict:
    """Build valid minimal flight values."""

    return {
        "departure_airport_id": 100,
        "arrival_airport_id": 200,
        "departure_on": departure_on,
        "status": status,
    }


def seed_flight_references(
    session: Session,
    *,
    user_ids: list[UUID],
) -> None:
    """Insert valid users and airports required by flight tests."""

    for index, user_id in enumerate(user_ids):
        session.add(
            User(
                id=user_id,
                username=f"flight_user_{index}",
                email=f"flight_user_{index}@example.com",
                display_name=f"Flight User {index}",
                password_hash="test-not-used-for-login",
            )
        )

    session.add_all(
        [
            Airport(
                id=100,
                ident="TEST-DEP",
                name="Test Departure Airport",
                source_country_code=None,
                country_code=None,
                latitude=38.7,
                longitude=-9.1,
                type="small_airport",
                scheduled_service=False,
            ),
            Airport(
                id=200,
                ident="TEST-ARR",
                name="Test Arrival Airport",
                source_country_code=None,
                country_code=None,
                latitude=41.1,
                longitude=-8.6,
                type="small_airport",
                scheduled_service=False,
            ),
        ]
    )

    session.flush()


def test_create_flight_assigns_owner(session: Session) -> None:
    repository = FlightRepository(session)
    user_id = uuid4()

    seed_flight_references(
        session,
        user_ids=[user_id],
    )

    flight = repository.create(
        user_id=user_id,
        values=flight_values(),
    )

    assert flight.id is not None
    assert flight.user_id == user_id
    assert flight.departure_airport_id == 100
    assert flight.arrival_airport_id == 200


def test_get_for_user_enforces_ownership(session: Session) -> None:
    repository = FlightRepository(session)

    owner_id = uuid4()
    another_user_id = uuid4()

    seed_flight_references(
        session,
        user_ids=[owner_id, another_user_id],
    )

    flight = repository.create(
        user_id=owner_id,
        values=flight_values(),
    )

    owned_flight = repository.get_for_user(
        flight_id=flight.id,
        user_id=owner_id,
    )

    other_user_flight = repository.get_for_user(
        flight_id=flight.id,
        user_id=another_user_id,
    )

    assert owned_flight is not None
    assert owned_flight.id == flight.id

    assert other_user_flight is None


def test_list_for_user_excludes_other_users(
    session: Session,
) -> None:
    repository = FlightRepository(session)

    owner_id = uuid4()
    another_user_id = uuid4()

    seed_flight_references(
        session,
        user_ids=[owner_id, another_user_id],
    )

    first = repository.create(
        user_id=owner_id,
        values=flight_values(),
    )

    repository.create(
        user_id=another_user_id,
        values=flight_values(),
    )

    flights, total = repository.list_for_user(
        user_id=owner_id,
        limit=20,
        offset=0,
    )

    assert total == 1
    assert [flight.id for flight in flights] == [first.id]


def test_list_can_filter_by_status(session: Session) -> None:
    repository = FlightRepository(session)
    user_id = uuid4()

    seed_flight_references(
        session,
        user_ids=[user_id],
    )

    repository.create(
        user_id=user_id,
        values=flight_values(status="flown"),
    )

    planned = repository.create(
        user_id=user_id,
        values=flight_values(
            departure_on=date(2027, 6, 10),
            status="planned",
        ),
    )

    flights, total = repository.list_for_user(
        user_id=user_id,
        status="planned",
        limit=20,
        offset=0,
    )

    assert total == 1
    assert [flight.id for flight in flights] == [planned.id]


def test_list_order_is_deterministic(session: Session) -> None:
    repository = FlightRepository(session)
    user_id = uuid4()

    seed_flight_references(
        session,
        user_ids=[user_id],
    )

    older = repository.create(
        user_id=user_id,
        values=flight_values(
            departure_on=date(2024, 1, 1),
        ),
    )

    newer = repository.create(
        user_id=user_id,
        values=flight_values(
            departure_on=date(2025, 1, 1),
        ),
    )

    flights, total = repository.list_for_user(
        user_id=user_id,
        limit=20,
        offset=0,
    )

    assert total == 2

    assert [flight.id for flight in flights] == [
        newer.id,
        older.id,
    ]


def test_list_supports_pagination(session: Session) -> None:
    repository = FlightRepository(session)
    user_id = uuid4()

    seed_flight_references(
        session,
        user_ids=[user_id],
    )

    for year in (2023, 2024, 2025):
        repository.create(
            user_id=user_id,
            values=flight_values(
                departure_on=date(year, 1, 1),
            ),
        )

    flights, total = repository.list_for_user(
        user_id=user_id,
        limit=1,
        offset=1,
    )

    assert total == 3
    assert len(flights) == 1

    assert flights[0].departure_on == date(2024, 1, 1)


def test_update_changes_persisted_fields(
    session: Session,
) -> None:
    repository = FlightRepository(session)
    user_id = uuid4()

    seed_flight_references(
        session,
        user_ids=[user_id],
    )

    flight = repository.create(
        user_id=user_id,
        values=flight_values(),
    )

    repository.update(
        flight=flight,
        values={
            "flight_number": "TP1920",
            "seat": "12A",
        },
    )

    session.expire(flight)

    updated = repository.get_for_user(
        flight_id=flight.id,
        user_id=user_id,
    )

    assert updated is not None
    assert updated.flight_number == "TP1920"
    assert updated.seat == "12A"


def test_delete_for_user_enforces_ownership(
    session: Session,
) -> None:
    repository = FlightRepository(session)

    owner_id = uuid4()
    another_user_id = uuid4()

    seed_flight_references(
        session,
        user_ids=[owner_id, another_user_id],
    )

    flight = repository.create(
        user_id=owner_id,
        values=flight_values(),
    )

    assert not repository.delete_for_user(
        flight_id=flight.id,
        user_id=another_user_id,
    )

    assert (
        repository.get_for_user(
            flight_id=flight.id,
            user_id=owner_id,
        )
        is not None
    )

    assert repository.delete_for_user(
        flight_id=flight.id,
        user_id=owner_id,
    )

    assert (
        repository.get_for_user(
            flight_id=flight.id,
            user_id=owner_id,
        )
        is None
    )


def test_duplicate_flights_are_allowed(
    session: Session,
) -> None:
    repository = FlightRepository(session)
    user_id = uuid4()

    seed_flight_references(
        session,
        user_ids=[user_id],
    )

    first = repository.create(
        user_id=user_id,
        values={
            **flight_values(),
            "flight_number": "TP1920",
        },
    )

    second = repository.create(
        user_id=user_id,
        values={
            **flight_values(),
            "flight_number": "TP1920",
        },
    )

    assert first.id != second.id

    flights, total = repository.list_for_user(
        user_id=user_id,
        limit=20,
        offset=0,
    )

    assert total == 2
    assert len(flights) == 2


def test_database_rejects_invalid_airport_references(
    session: Session,
) -> None:
    """Foreign-key constraints must actually be enforced."""

    repository = FlightRepository(session)
    user_id = uuid4()

    seed_flight_references(
        session,
        user_ids=[user_id],
    )

    from sqlalchemy.exc import IntegrityError

    with pytest.raises(IntegrityError):
        repository.create(
            user_id=user_id,
            values={
                **flight_values(),
                "departure_airport_id": 999999,
            },
        )
