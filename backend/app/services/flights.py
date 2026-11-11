"""Application services for user-owned flight records."""

from uuid import UUID

from sqlalchemy import Engine, select
from sqlalchemy.orm import Session

from app.db.write_transactions import sqlite_write_session
from app.domain.flights import (
    FlightStatus,
    merge_flight_changes,
)
from app.models.airline import Airline
from app.models.airport import Airport
from app.models.flight import Flight
from app.repositories.flights import FlightRepository
from app.schemas.flights import FlightCreate, FlightUpdate


class FlightNotFound(Exception):
    """Flight does not exist or does not belong to the user."""


class AirportNotFound(Exception):
    """A referenced airport does not exist."""


class AirlineNotFound(Exception):
    """A referenced airline does not exist."""


class InvalidFlightData(Exception):
    """The requested flight state violates domain rules."""


def _validate_references(
    *,
    session: Session,
    departure_airport_id: int,
    arrival_airport_id: int,
    airline_id: int | None,
) -> None:
    """Validate referenced catalog records within the transaction."""

    airport_ids = {
        departure_airport_id,
        arrival_airport_id,
    }

    existing_airport_ids = set(
        session.scalars(select(Airport.id).where(Airport.id.in_(airport_ids))).all()
    )

    missing_airport_ids = airport_ids - existing_airport_ids

    if missing_airport_ids:
        raise AirportNotFound("One or more referenced airports do not exist.")

    if airline_id is not None:
        existing_airline_id = session.scalar(select(Airline.id).where(Airline.id == airline_id))

        if existing_airline_id is None:
            raise AirlineNotFound("Referenced airline does not exist.")


def _current_flight_values(flight: Flight) -> dict:
    """Extract fields relevant to flight domain validation."""

    return {
        "departure_airport_id": flight.departure_airport_id,
        "arrival_airport_id": flight.arrival_airport_id,
        "airline_id": flight.airline_id,
        "airline_name": flight.airline_name,
        "flight_number": flight.flight_number,
        "departure_on": flight.departure_on,
        "departure_time": flight.departure_time,
        "arrival_on": flight.arrival_on,
        "arrival_time": flight.arrival_time,
        "status": FlightStatus(flight.status),
        "aircraft_type": flight.aircraft_type,
        "aircraft_registration": flight.aircraft_registration,
        "seat": flight.seat,
        "cabin_class": flight.cabin_class,
        "notes": flight.notes,
    }


def create_flight(
    *,
    engine: Engine,
    user_id: UUID,
    payload: FlightCreate,
) -> Flight:
    """Create a personal flight in an atomic transaction."""

    values = payload.model_dump()

    with sqlite_write_session(engine) as session:
        _validate_references(
            session=session,
            departure_airport_id=payload.departure_airport_id,
            arrival_airport_id=payload.arrival_airport_id,
            airline_id=payload.airline_id,
        )

        repository = FlightRepository(session)

        flight = repository.create(
            user_id=user_id,
            values=values,
        )

        session.refresh(flight)

        return flight


def get_flight(
    *,
    engine: Engine,
    user_id: UUID,
    flight_id: UUID,
) -> Flight:
    """Retrieve a flight belonging to the authenticated user."""

    with Session(engine) as session:
        repository = FlightRepository(session)

        flight = repository.get_for_user(
            flight_id=flight_id,
            user_id=user_id,
        )

        if flight is None:
            raise FlightNotFound("Flight not found.")

        return flight


def list_flights(
    *,
    engine: Engine,
    user_id: UUID,
    limit: int = 20,
    offset: int = 0,
    status: FlightStatus | None = None,
) -> tuple[list[Flight], int]:
    """List only the authenticated user's flights."""

    with Session(engine) as session:
        repository = FlightRepository(session)

        return repository.list_for_user(
            user_id=user_id,
            limit=limit,
            offset=offset,
            status=status.value if status is not None else None,
        )


def update_flight(
    *,
    engine: Engine,
    user_id: UUID,
    flight_id: UUID,
    payload: FlightUpdate,
) -> Flight:
    """Update an owned flight after validating its complete final state."""

    with sqlite_write_session(engine) as session:
        repository = FlightRepository(session)

        flight = repository.get_for_user(
            flight_id=flight_id,
            user_id=user_id,
        )

        if flight is None:
            raise FlightNotFound("Flight not found.")

        changes = payload.model_dump(exclude_unset=True)

        current = _current_flight_values(flight)

        try:
            merged = merge_flight_changes(
                current=current,
                changes=changes,
            )
        except ValueError as error:
            raise InvalidFlightData(str(error)) from error

        _validate_references(
            session=session,
            departure_airport_id=merged["departure_airport_id"],
            arrival_airport_id=merged["arrival_airport_id"],
            airline_id=merged["airline_id"],
        )

        updated = repository.update(
            flight=flight,
            values=changes,
        )

        session.refresh(updated)

        return updated


def delete_flight(
    *,
    engine: Engine,
    user_id: UUID,
    flight_id: UUID,
) -> None:
    """Delete a flight belonging to the authenticated user."""

    with sqlite_write_session(engine) as session:
        repository = FlightRepository(session)

        deleted = repository.delete_for_user(
            flight_id=flight_id,
            user_id=user_id,
        )

        if not deleted:
            raise FlightNotFound("Flight not found.")
