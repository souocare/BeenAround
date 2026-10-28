"""Individual city visits belonging to users."""

from datetime import date
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, Date, ForeignKey, Index, Integer, Uuid, String
from sqlalchemy.orm import Mapped, mapped_column
from app.domain.visit_date_constraints import precision_check, range_check

from app.db.base import Base
from app.db.mixins import TimestampMixin


class CityVisit(TimestampMixin, Base):
    """A user's individual visit to a city."""

    __tablename__ = "city_visits"

    __table_args__ = (
        CheckConstraint(
            precision_check("started_on", "started_on_precision"),
            name="ck_city_visits_start_precision",
        ),
        CheckConstraint(
            precision_check("ended_on", "ended_on_precision"),
            name="ck_city_visits_end_precision",
        ),
        CheckConstraint(
            range_check(),
            name="ck_city_visits_valid_dates",
        ),
        Index(
            "ix_city_visits_user_city",
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

    city_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("cities.id", ondelete="RESTRICT"),
        nullable=False,
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