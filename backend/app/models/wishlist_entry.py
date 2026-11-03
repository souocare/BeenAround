"""Global wishlist entries belonging to users."""

from uuid import UUID, uuid4

from sqlalchemy import (
    CheckConstraint,
    ForeignKey,
    Index,
    Integer,
    String,
    Uuid,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.mixins import TimestampMixin


class WishlistEntry(TimestampMixin, Base):
    """A country or city a user explicitly wishes to visit."""

    __tablename__ = "wishlist_entries"

    __table_args__ = (
        CheckConstraint(
            "("
            "country_code IS NOT NULL AND city_id IS NULL"
            ") OR ("
            "country_code IS NULL AND city_id IS NOT NULL"
            ")",
            name="ck_wishlist_entries_exactly_one_destination",
        ),
        Index(
            "ix_wishlist_entries_user_country_unique",
            "user_id",
            "country_code",
            unique=True,
        ),
        Index(
            "ix_wishlist_entries_user_city_unique",
            "user_id",
            "city_id",
            unique=True,
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

    country_code: Mapped[str | None] = mapped_column(
        String(2),
        ForeignKey("countries.code", ondelete="RESTRICT"),
        nullable=True,
    )

    city_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey("cities.id", ondelete="RESTRICT"),
        nullable=True,
    )
