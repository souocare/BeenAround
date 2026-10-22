from datetime import date
from uuid import UUID, uuid4

from sqlalchemy import CheckConstraint, Date, ForeignKey, Index, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.mixins import TimestampMixin


class CountryVisit(TimestampMixin, Base):
    """A user's individual visit to a country."""

    __tablename__ = "country_visits"

    __table_args__ = (
        CheckConstraint(
            "ended_on IS NULL OR (started_on IS NOT NULL AND ended_on >= started_on)",
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

    started_on: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
    )

    ended_on: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
    )
