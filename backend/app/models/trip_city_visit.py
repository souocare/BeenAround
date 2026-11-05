"""Associations between Trips and existing city visits."""

from uuid import UUID

from sqlalchemy import ForeignKey, Index, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class TripCityVisit(Base):
    """Associate a Trip with an independent city visit."""

    __tablename__ = "trip_city_visits"

    __table_args__ = (
        Index(
            "ix_trip_city_visits_city_visit_id",
            "city_visit_id",
        ),
    )

    trip_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("trips.id", ondelete="CASCADE"),
        primary_key=True,
    )

    city_visit_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("city_visits.id", ondelete="CASCADE"),
        primary_key=True,
    )