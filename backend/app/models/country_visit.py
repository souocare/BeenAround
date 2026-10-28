from datetime import date
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, Date, ForeignKey, Index, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column
from app.domain.visit_date_constraints import precision_check, range_check

from app.db.base import Base
from app.db.mixins import TimestampMixin


class CountryVisit(TimestampMixin, Base):
    """A user's individual visit to a country."""

    __tablename__ = "country_visits"

    __table_args__ = (
        CheckConstraint(
            precision_check("started_on", "started_on_precision"),
            name="ck_country_visits_start_precision",
        ),
        CheckConstraint(
            precision_check("ended_on", "ended_on_precision"),
            name="ck_country_visits_end_precision",
        ),
        CheckConstraint(
            range_check(),
            name="ck_country_visits_valid_dates",
        ),
        Index(
            "ix_country_visits_user_country",
            "user_id",
            "country_code",
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
