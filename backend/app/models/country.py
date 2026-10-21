from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Country(Base):
    """Country in the shared geographic catalog."""

    __tablename__ = "countries"

    code: Mapped[str] = mapped_column(
        String(2),
        primary_key=True,
    )

    name: Mapped[str] = mapped_column(
        String(120),
        nullable=False,
    )

    alpha3_code: Mapped[str] = mapped_column(
        String(3),
        nullable=False,
        unique=True,
    )
