"""Personal flight records."""

from datetime import date, time
from uuid import UUID, uuid4

from sqlalchemy import (
    CheckConstraint,
    Date,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    Time,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.mixins import TimestampMixin


class Flight(TimestampMixin, Base):
    """A flight segment recorded by a BeenAround user."""

    __tablename__ = "flights"

    __table_args__ = (
        CheckConstraint(
            "departure_airport_id != arrival_airport_id",
            name="ck_flights_distinct_airports",
        ),
        CheckConstraint(
            "status IN ('flown', 'planned')",
            name="ck_flights_valid_status",
        ),
        CheckConstraint(
            "cabin_class IS NULL OR cabin_class IN "
            "('economy', 'premium_economy', 'business', 'first')",
            name="ck_flights_valid_cabin_class",
        ),
        CheckConstraint(
            "airline_name IS NULL OR length(trim(airline_name)) > 0",
            name="ck_flights_airline_name_not_blank",
        ),
        CheckConstraint(
            "airline_id IS NULL OR airline_name IS NULL",
            name="ck_flights_airline_selection",
        ),
        CheckConstraint(
            "arrival_time IS NULL OR arrival_on IS NOT NULL",
            name="ck_flights_arrival_time_requires_date",
        ),
        Index(
            "ix_flights_user_departure",
            "user_id",
            "departure_on",
        ),
        Index(
            "ix_flights_user_status",
            "user_id",
            "status",
        ),
    )

    id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        primary_key=True,
        default=uuid4,
    )

    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    departure_airport_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("airports.id", ondelete="RESTRICT"),
        nullable=False,
    )

    arrival_airport_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("airports.id", ondelete="RESTRICT"),
        nullable=False,
    )

    airline_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey("airlines.id", ondelete="RESTRICT"),
        nullable=True,
    )

    airline_name: Mapped[str | None] = mapped_column(
        String(200),
        nullable=True,
    )

    flight_number: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
    )

    departure_on: Mapped[date] = mapped_column(
        Date,
        nullable=False,
    )

    departure_time: Mapped[time | None] = mapped_column(
        Time(timezone=False),
        nullable=True,
    )

    arrival_on: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
    )

    arrival_time: Mapped[time | None] = mapped_column(
        Time(timezone=False),
        nullable=True,
    )

    status: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
    )

    aircraft_type: Mapped[str | None] = mapped_column(
        String(120),
        nullable=True,
    )

    aircraft_registration: Mapped[str | None] = mapped_column(
        String(30),
        nullable=True,
    )

    seat: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
    )

    cabin_class: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
    )

    notes: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )
