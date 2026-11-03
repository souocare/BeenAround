"""Historical residences belonging to users."""

from datetime import date
from uuid import UUID, uuid4

from sqlalchemy import (
    CheckConstraint,
    Date,
    ForeignKey,
    Index,
    Integer,
    String,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.mixins import TimestampMixin
from app.domain.visit_date_constraints import (
    precision_check,
    range_check,
)


class Residence(TimestampMixin, Base):
    """A historical period during which a user lived in a destination."""

    __tablename__ = "residences"

    __table_args__ = (
        CheckConstraint(
            precision_check("started_on", "started_on_precision"),
            name="ck_residences_start_precision",
        ),
        CheckConstraint(
            precision_check("ended_on", "ended_on_precision"),
            name="ck_residences_end_precision",
        ),
        CheckConstraint(
            "started_on_precision IN ('day', 'month')",
            name="ck_residences_start_minimum_month_precision",
        ),
        CheckConstraint(
            "ended_on_precision IN ('day', 'month')",
            name="ck_residences_end_minimum_month_precision",
        ),
        CheckConstraint(
            range_check(),
            name="ck_residences_valid_dates",
        ),
        Index(
            "ix_residences_user_country",
            "user_id",
            "country_code",
        ),
        Index(
            "ix_residences_user_city",
            "user_id",
            "city_id",
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

    country_code: Mapped[str] = mapped_column(
        String(2),
        ForeignKey("countries.code", ondelete="RESTRICT"),
        nullable=False,
    )

    city_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey("cities.id", ondelete="RESTRICT"),
        nullable=True,
    )

    started_on: Mapped[date] = mapped_column(
        Date,
        nullable=False,
    )

    ended_on: Mapped[date] = mapped_column(
        Date,
        nullable=False,
    )

    started_on_precision: Mapped[str] = mapped_column(
        String(5),
        nullable=False,
    )

    ended_on_precision: Mapped[str] = mapped_column(
        String(5),
        nullable=False,
    )