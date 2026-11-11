"""Shared airport catalog model."""

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Airport(Base):
    """Airport in the shared OurAirports catalog."""

    __tablename__ = "airports"

    __table_args__ = (
        CheckConstraint(
            "latitude >= -90 AND latitude <= 90",
            name="ck_airports_valid_latitude",
        ),
        CheckConstraint(
            "longitude >= -180 AND longitude <= 180",
            name="ck_airports_valid_longitude",
        ),
        Index(
            "ix_airports_country_name",
            "country_code",
            "name",
        ),
        Index(
            "ix_airports_iata_code",
            "iata_code",
        ),
        Index(
            "ix_airports_icao_code",
            "icao_code",
        ),
        Index(
            "ix_airports_municipality",
            "municipality",
        ),
    )

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=False,
    )

    ident: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        unique=True,
    )

    iata_code: Mapped[str | None] = mapped_column(
        String(3),
        nullable=True,
    )

    icao_code: Mapped[str | None] = mapped_column(
        String(4),
        nullable=True,
    )

    name: Mapped[str] = mapped_column(
        String(200),
        nullable=False,
    )

    municipality: Mapped[str | None] = mapped_column(
        String(200),
        nullable=True,
    )

    country_code: Mapped[str | None] = mapped_column(
        String(2),
        ForeignKey("countries.code", ondelete="RESTRICT"),
        nullable=True,
    )

    latitude: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
    )

    longitude: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
    )

    type: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
    )

    scheduled_service: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
    )

    source_country_code: Mapped[str | None] = mapped_column(
        String(2),
        nullable=True,
    )