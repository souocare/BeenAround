"""Associations between Trips and existing country visits."""

from uuid import UUID

from sqlalchemy import ForeignKey, Index, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class TripCountryVisit(Base):
    """Associate a Trip with an independent country visit."""

    __tablename__ = "trip_country_visits"

    __table_args__ = (
        Index(
            "ix_trip_country_visits_country_visit_id",
            "country_visit_id",
        ),
    )

    trip_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("trips.id", ondelete="CASCADE"),
        primary_key=True,
    )

    country_visit_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("country_visits.id", ondelete="CASCADE"),
        primary_key=True,
    )