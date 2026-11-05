"""Application services for user-owned Trips."""

from uuid import UUID

from sqlalchemy import Engine

from app.db.write_transactions import sqlite_write_session
from app.domain.trip_dates import resolve_trip_date_update
from app.domain.visit_dates import DatePrecision
from app.models.trip import Trip
from app.repositories.trips import TripRepository
from app.schemas.trips import TripCreate, TripUpdate


class TripNotFound(Exception):
    """The requested Trip does not exist or is not owned by the user."""


class InvalidTripDates(Exception):
    """The requested Trip date update violates domain rules."""


def create_trip(
    *,
    engine: Engine,
    user_id: UUID,
    payload: TripCreate,
) -> Trip:
    """Create a user-owned Trip atomically."""

    with sqlite_write_session(engine) as session:
        repository = TripRepository(session)

        trip = repository.create(
            user_id=user_id,
            name=payload.name,
            description=payload.description,
            started_on=payload.started_on,
            started_on_precision=payload.started_on_precision,
            ended_on=payload.ended_on,
            ended_on_precision=payload.ended_on_precision,
        )

        session.refresh(trip)

        return trip


def update_trip(
    *,
    engine: Engine,
    user_id: UUID,
    trip_id: UUID,
    payload: TripUpdate,
) -> Trip:
    """Update an owned Trip inside a SQLite write transaction."""

    with sqlite_write_session(engine) as session:
        repository = TripRepository(session)

        trip = repository.get_for_user(
            trip_id=trip_id,
            user_id=user_id,
        )

        if trip is None:
            raise TripNotFound("Trip not found.")

        changes = payload.model_dump(exclude_unset=True)

        date_changes = {
            key: value
            for key, value in changes.items()
            if key
            in {
                "started_on",
                "started_on_precision",
                "ended_on",
                "ended_on_precision",
            }
        }

        try:
            (
                started_on,
                started_precision,
                ended_on,
                ended_precision,
            ) = resolve_trip_date_update(
                current_started_on=trip.started_on,
                current_started_on_precision=(
                    DatePrecision(trip.started_on_precision)
                    if trip.started_on_precision is not None
                    else None
                ),
                current_ended_on=trip.ended_on,
                current_ended_on_precision=(
                    DatePrecision(trip.ended_on_precision)
                    if trip.ended_on_precision is not None
                    else None
                ),
                changes=date_changes,
            )

        except ValueError as error:
            raise InvalidTripDates(str(error)) from error

        updated = repository.update(
            trip=trip,
            name=changes.get("name", trip.name),
            description=changes.get("description", trip.description),
            started_on=started_on,
            started_on_precision=started_precision,
            ended_on=ended_on,
            ended_on_precision=ended_precision,
        )

        session.refresh(updated)

        return updated


def delete_trip(
    *,
    engine: Engine,
    user_id: UUID,
    trip_id: UUID,
) -> None:
    """Delete an owned Trip atomically."""

    with sqlite_write_session(engine) as session:
        repository = TripRepository(session)

        deleted = repository.delete_for_user(
            trip_id=trip_id,
            user_id=user_id,
        )

        if not deleted:
            raise TripNotFound("Trip not found.")
