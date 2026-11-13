"""Database integrity tests for Trip–Flight associations."""

from collections.abc import Generator
from datetime import date, time
from uuid import UUID, uuid4

import pytest
from sqlalchemy import create_engine, event, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.models.airline import Airline  # noqa: F401
from app.models.airport import Airport
from app.models.country import Country  # noqa: F401
from app.models.flight import Flight
from app.models.trip import Trip
from app.models.trip_flight import TripFlight
from app.models.user import User
from app.repositories.trip_associations import TripAssociationRepository


@pytest.fixture
def session() -> Generator[Session, None, None]:
    """Create an isolated SQLite database with foreign keys enabled."""

    engine = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )

    @event.listens_for(engine, "connect")
    def enable_foreign_keys(
        dbapi_connection,
        connection_record,
    ) -> None:
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    Base.metadata.create_all(engine)

    try:
        with Session(engine) as db:
            yield db
    finally:
        engine.dispose()


@pytest.fixture
def records(session: Session) -> dict[str, UUID]:
    """Seed owned Trips and independent personal flights."""

    user_id = uuid4()

    session.add(
        User(
            id=user_id,
            username="trip_flight_tester",
            email="trip_flight_tester@example.com",
            display_name="Trip Flight Tester",
            password_hash="test-hash",
        )
    )

    # Persist the user before inserting owned records.
    session.flush()

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

    trip_a = Trip(
        user_id=user_id,
        name="Portugal 2025",
    )

    trip_b = Trip(
        user_id=user_id,
        name="European Flights",
    )

    flight_a = Flight(
        user_id=user_id,
        departure_airport_id=100,
        arrival_airport_id=200,
        departure_on=date(2025, 9, 10),
        departure_time=time(10, 30),
        status="flown",
    )

    flight_b = Flight(
        user_id=user_id,
        departure_airport_id=200,
        arrival_airport_id=100,
        departure_on=date(2025, 9, 15),
        departure_time=time(18, 45),
        status="flown",
    )

    flight_c = Flight(
        user_id=user_id,
        departure_airport_id=100,
        arrival_airport_id=200,
        departure_on=date(2025, 8, 20),
        status="flown",
    )

    session.add_all(
        [
            trip_a,
            trip_b,
            flight_a,
            flight_b,
            flight_c,
        ]
    )

    session.commit()

    return {
        "user_id": user_id,
        "trip_a": trip_a.id,
        "trip_b": trip_b.id,
        "flight_a": flight_a.id,
        "flight_b": flight_b.id,
        "flight_c": flight_c.id,
    }


def association_count(session: Session) -> int:
    """Count persisted Trip–Flight associations."""

    return session.scalar(select(func.count()).select_from(TripFlight)) or 0


def test_can_associate_existing_flight(
    session: Session,
    records: dict[str, UUID],
) -> None:
    repository = TripAssociationRepository(session)

    created = repository.add_flight(
        trip_id=records["trip_a"],
        flight_id=records["flight_a"],
    )

    session.commit()

    assert created is True
    assert association_count(session) == 1

    flights = repository.list_flights(
        trip_id=records["trip_a"],
    )

    assert [flight.id for flight in flights] == [
        records["flight_a"],
    ]


def test_duplicate_association_is_idempotent(
    session: Session,
    records: dict[str, UUID],
) -> None:
    repository = TripAssociationRepository(session)

    first = repository.add_flight(
        trip_id=records["trip_a"],
        flight_id=records["flight_a"],
    )

    second = repository.add_flight(
        trip_id=records["trip_a"],
        flight_id=records["flight_a"],
    )

    session.commit()

    assert first is True
    assert second is False
    assert association_count(session) == 1


def test_same_flight_can_belong_to_multiple_trips(
    session: Session,
    records: dict[str, UUID],
) -> None:
    repository = TripAssociationRepository(session)

    assert repository.add_flight(
        trip_id=records["trip_a"],
        flight_id=records["flight_a"],
    )

    assert repository.add_flight(
        trip_id=records["trip_b"],
        flight_id=records["flight_a"],
    )

    session.commit()

    assert association_count(session) == 2

    assert [
        flight.id
        for flight in repository.list_flights(
            trip_id=records["trip_a"],
        )
    ] == [records["flight_a"]]

    assert [
        flight.id
        for flight in repository.list_flights(
            trip_id=records["trip_b"],
        )
    ] == [records["flight_a"]]


def test_trip_can_contain_multiple_flights_in_date_order(
    session: Session,
    records: dict[str, UUID],
) -> None:
    repository = TripAssociationRepository(session)

    # Insert in deliberately non-chronological order.
    for key in ("flight_b", "flight_a", "flight_c"):
        repository.add_flight(
            trip_id=records["trip_a"],
            flight_id=records[key],
        )

    session.commit()

    flights = repository.list_flights(
        trip_id=records["trip_a"],
    )

    assert [flight.id for flight in flights] == [
        records["flight_c"],
        records["flight_a"],
        records["flight_b"],
    ]


def test_removing_association_preserves_flight(
    session: Session,
    records: dict[str, UUID],
) -> None:
    repository = TripAssociationRepository(session)

    repository.add_flight(
        trip_id=records["trip_a"],
        flight_id=records["flight_a"],
    )

    session.commit()

    removed = repository.remove_flight(
        trip_id=records["trip_a"],
        flight_id=records["flight_a"],
    )

    session.commit()

    assert removed is True
    assert association_count(session) == 0

    assert (
        session.get(
            Flight,
            records["flight_a"],
        )
        is not None
    )


def test_removing_missing_association_returns_false(
    session: Session,
    records: dict[str, UUID],
) -> None:
    repository = TripAssociationRepository(session)

    removed = repository.remove_flight(
        trip_id=records["trip_a"],
        flight_id=records["flight_a"],
    )

    assert removed is False
    assert association_count(session) == 0


def test_removing_one_trip_association_preserves_others(
    session: Session,
    records: dict[str, UUID],
) -> None:
    repository = TripAssociationRepository(session)

    repository.add_flight(
        trip_id=records["trip_a"],
        flight_id=records["flight_a"],
    )

    repository.add_flight(
        trip_id=records["trip_b"],
        flight_id=records["flight_a"],
    )

    session.commit()

    repository.remove_flight(
        trip_id=records["trip_a"],
        flight_id=records["flight_a"],
    )

    session.commit()

    assert association_count(session) == 1

    assert (
        repository.list_flights(
            trip_id=records["trip_a"],
        )
        == []
    )

    assert [
        flight.id
        for flight in repository.list_flights(
            trip_id=records["trip_b"],
        )
    ] == [records["flight_a"]]


def test_deleting_trip_cascades_associations_only(
    session: Session,
    records: dict[str, UUID],
) -> None:
    repository = TripAssociationRepository(session)

    repository.add_flight(
        trip_id=records["trip_a"],
        flight_id=records["flight_a"],
    )

    session.commit()

    trip = session.get(Trip, records["trip_a"])

    assert trip is not None

    session.delete(trip)
    session.commit()

    assert association_count(session) == 0

    assert (
        session.get(
            Flight,
            records["flight_a"],
        )
        is not None
    )


def test_deleting_flight_cascades_associations_only(
    session: Session,
    records: dict[str, UUID],
) -> None:
    repository = TripAssociationRepository(session)

    repository.add_flight(
        trip_id=records["trip_a"],
        flight_id=records["flight_a"],
    )

    session.commit()

    flight = session.get(Flight, records["flight_a"])

    assert flight is not None

    session.delete(flight)
    session.commit()

    assert association_count(session) == 0

    assert (
        session.get(
            Trip,
            records["trip_a"],
        )
        is not None
    )


def test_foreign_keys_reject_nonexistent_records(
    session: Session,
    records: dict[str, UUID],
) -> None:
    session.add(
        TripFlight(
            trip_id=records["trip_a"],
            flight_id=uuid4(),
        )
    )

    with pytest.raises(IntegrityError):
        session.commit()


def test_composite_primary_key_rejects_duplicate_rows(
    session: Session,
    records: dict[str, UUID],
) -> None:
    session.add(
        TripFlight(
            trip_id=records["trip_a"],
            flight_id=records["flight_a"],
        )
    )

    session.commit()

    session.add(
        TripFlight(
            trip_id=records["trip_a"],
            flight_id=records["flight_a"],
        )
    )

    with pytest.raises(IntegrityError):
        session.commit()
