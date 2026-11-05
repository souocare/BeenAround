"""Trips belonging to BeenAround users."""

from datetime import date
from uuid import UUID, uuid4

from sqlalchemy import (
    CheckConstraint,
    Date,
    ForeignKey,
    Index,
    String,
    Text,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.mixins import TimestampMixin
from app.domain.visit_date_constraints import (
    optional_range_check,
    precision_check,
)


class Trip(TimestampMixin, Base):
    """A user-owned journey that may organize independent travel records."""

    __tablename__ = "trips"

    __table_args__ = (
        CheckConstraint(
            "length(trim(name)) > 0",
            name="ck_trips_name_not_blank",
        ),
        CheckConstraint(
            precision_check(
                "started_on",
                "started_on_precision",
            ),
            name="ck_trips_start_precision",
        ),
        CheckConstraint(
            precision_check(
                "ended_on",
                "ended_on_precision",
            ),
            name="ck_trips_end_precision",
        ),
        CheckConstraint(
            optional_range_check(),
            name="ck_trips_valid_dates",
        ),
        Index(
            "ix_trips_user_created",
            "user_id",
            "created_at",
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

    name: Mapped[str] = mapped_column(
        String(160),
        nullable=False,
    )

    description: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        default=None,
    )

    started_on: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
        default=None,
    )

    started_on_precision: Mapped[str | None] = mapped_column(
        String(5),
        nullable=True,
        default=None,
    )

    ended_on: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
        default=None,
    )

    ended_on_precision: Mapped[str | None] = mapped_column(
        String(5),
        nullable=True,
        default=None,
    )
