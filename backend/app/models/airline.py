"""Shared airline catalog model."""

from sqlalchemy import CheckConstraint, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Airline(Base):
    """Airline in the shared aviation catalog."""

    __tablename__ = "airlines"

    __table_args__ = (
        CheckConstraint(
            "iata_code IS NULL OR length(iata_code) = 2",
            name="ck_airlines_iata_code_length",
        ),
        CheckConstraint(
            "icao_code IS NULL OR length(icao_code) = 3",
            name="ck_airlines_icao_code_length",
        ),
        Index(
            "ix_airlines_name",
            "name",
        ),
        Index(
            "ix_airlines_iata_code",
            "iata_code",
        ),
        Index(
            "ix_airlines_icao_code",
            "icao_code",
        ),
    )

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=True,
    )

    name: Mapped[str] = mapped_column(
        String(200),
        nullable=False,
    )

    iata_code: Mapped[str | None] = mapped_column(
        String(2),
        nullable=True,
    )

    icao_code: Mapped[str | None] = mapped_column(
        String(3),
        nullable=True,
    )

    callsign: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
    )

    country_name: Mapped[str | None] = mapped_column(
        String(120),
        nullable=True,
    )

    source_key: Mapped[str | None] = mapped_column(
        String(150),
        nullable=True,
        unique=True,
    )
