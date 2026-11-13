"""Associations between Trips and existing personal flights."""

from uuid import UUID

from sqlalchemy import ForeignKey, Index, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class TripFlight(Base):
    """Associate a Trip with an independent personal flight."""

    __tablename__ = "trip_flights"

    __table_args__ = (
        Index(
            "ix_trip_flights_flight_id",
            "flight_id",
        ),
    )

    trip_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("trips.id", ondelete="CASCADE"),
        primary_key=True,
    )

    flight_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("flights.id", ondelete="CASCADE"),
        primary_key=True,
    )