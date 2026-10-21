"""Country catalog database queries."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.country import Country


class CountryRepository:
    """Read operations for the shared country catalog."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def list_all(self) -> list[Country]:
        """Return all countries ordered by name."""

        statement = select(Country).order_by(
            Country.name,
            Country.code,
        )

        return list(self._session.scalars(statement).all())

    def get_by_code(self, code: str) -> Country | None:
        """Return a country by its ISO alpha-2 code."""

        return self._session.get(Country, code)
