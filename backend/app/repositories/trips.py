"""Database queries for user-owned Trips."""

from datetime import date
from uuid import UUID

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.domain.visit_dates import DatePrecision
from app.models.trip import Trip


class TripRepository:
    """Persistence operations for Trips."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def list_for_user(self, user_id: UUID) -> list[Trip]:
        """Return only Trips belonging to the given user."""

        statement = (
            select(Trip)
            .where(Trip.user_id == user_id)
            .order_by(
                Trip.created_at.desc(),
                Trip.id.desc(),
            )
        )

        return list(self._session.scalars(statement).all())

    def get_for_user(
        self,
        *,
        trip_id: UUID,
        user_id: UUID,
    ) -> Trip | None:
        """Retrieve a Trip only when owned by the user."""

        statement = select(Trip).where(
            Trip.id == trip_id,
            Trip.user_id == user_id,
        )

        return self._session.scalar(statement)

    def create(
        self,
        *,
        user_id: UUID,
        name: str,
        description: str | None,
        started_on: date | None,
        started_on_precision: DatePrecision | None,
        ended_on: date | None,
        ended_on_precision: DatePrecision | None,
    ) -> Trip:
        """Add a new Trip to the current transaction."""

        trip = Trip(
            user_id=user_id,
            name=name,
            description=description,
            started_on=started_on,
            started_on_precision=started_on_precision,
            ended_on=ended_on,
            ended_on_precision=ended_on_precision,
        )

        self._session.add(trip)
        self._session.flush()

        return trip

    def update(
        self,
        *,
        trip: Trip,
        name: str,
        description: str | None,
        started_on: date | None,
        started_on_precision: DatePrecision | None,
        ended_on: date | None,
        ended_on_precision: DatePrecision | None,
    ) -> Trip:
        """Apply validated changes to an ownership-checked Trip."""

        trip.name = name
        trip.description = description

        trip.started_on = started_on
        trip.started_on_precision = started_on_precision

        trip.ended_on = ended_on
        trip.ended_on_precision = ended_on_precision

        self._session.flush()

        return trip

    def delete_for_user(
        self,
        *,
        trip_id: UUID,
        user_id: UUID,
    ) -> bool:
        """Delete a Trip only when owned by the user."""

        statement = delete(Trip).where(
            Trip.id == trip_id,
            Trip.user_id == user_id,
        )

        result = self._session.execute(statement)

        return result.rowcount == 1
