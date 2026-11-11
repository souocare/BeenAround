"""Persistence operations for user-owned flight records."""

from datetime import date
from typing import Any
from uuid import UUID

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.models.flight import Flight


class FlightRepository:
    """Manage flights belonging to a specific user."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def create(
        self,
        *,
        user_id: UUID,
        values: dict[str, Any],
    ) -> Flight:
        """Add a new user-owned flight to the current transaction."""

        flight = Flight(
            user_id=user_id,
            **values,
        )

        self._session.add(flight)
        self._session.flush()

        return flight

    def get_for_user(
        self,
        *,
        flight_id: UUID,
        user_id: UUID,
    ) -> Flight | None:
        """Return a flight only when owned by the given user."""

        statement = select(Flight).where(
            Flight.id == flight_id,
            Flight.user_id == user_id,
        )

        return self._session.scalar(statement)

    def list_for_user(
        self,
        *,
        user_id: UUID,
        limit: int,
        offset: int,
        status: str | None = None,
    ) -> tuple[list[Flight], int]:
        """Return a paginated list of the user's flights."""

        conditions = [Flight.user_id == user_id]

        if status is not None:
            conditions.append(Flight.status == status)

        total = (
            self._session.scalar(select(func.count()).select_from(Flight).where(*conditions)) or 0
        )

        statement = (
            select(Flight)
            .where(*conditions)
            .order_by(
                Flight.departure_on.desc(),
                Flight.created_at.desc(),
                Flight.id.desc(),
            )
            .limit(limit)
            .offset(offset)
        )

        flights = list(self._session.scalars(statement).all())

        return flights, total

    def update(
        self,
        *,
        flight: Flight,
        values: dict[str, Any],
    ) -> Flight:
        """Apply an already validated state to an owned flight.

        The service must first load the flight using get_for_user()
        and validate the resulting state.
        """

        for field, value in values.items():
            setattr(flight, field, value)

        self._session.flush()

        return flight

    def delete_for_user(
        self,
        *,
        flight_id: UUID,
        user_id: UUID,
    ) -> bool:
        """Delete an owned flight without exposing other users' records."""

        statement = delete(Flight).where(
            Flight.id == flight_id,
            Flight.user_id == user_id,
        )

        result = self._session.execute(statement)

        return result.rowcount > 0
