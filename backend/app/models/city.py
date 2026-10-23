from sqlalchemy import BigInteger, CheckConstraint, Float, ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class City(Base):
    """City in the shared GeoNames geographic catalog."""

    __tablename__ = "cities"

    __table_args__ = (
        CheckConstraint(
            "latitude >= -90 AND latitude <= 90",
            name="ck_cities_valid_latitude",
        ),
        CheckConstraint(
            "longitude >= -180 AND longitude <= 180",
            name="ck_cities_valid_longitude",
        ),
        CheckConstraint(
            "population IS NULL OR population >= 0",
            name="ck_cities_valid_population",
        ),
        Index("ix_cities_country_name", "country_code", "name"),
    )

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        autoincrement=False,
    )

    country_code: Mapped[str] = mapped_column(
        String(2),
        ForeignKey("countries.code", ondelete="RESTRICT"),
        nullable=False,
    )

    name: Mapped[str] = mapped_column(
        String(200),
        nullable=False,
    )

    ascii_name: Mapped[str | None] = mapped_column(
        String(200),
        nullable=True,
    )

    latitude: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    longitude: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    population: Mapped[int | None] = mapped_column(
        BigInteger,
        nullable=True,
    )

    feature_code: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
    )