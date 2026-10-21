"""Country visit database queries."""

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.country_visit import CountryVisit


class CountryVisitRepository:
    """Persistence operations for country visits."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def list_for_user(self, user_id: UUID) -> list[CountryVisit]:
        """Return only the country visits owned by a user."""

        statement = (
            select(CountryVisit)
            .where(CountryVisit.user_id == user_id)
            .order_by(
                CountryVisit.created_at.desc(),
                CountryVisit.id.desc(),
            )
        )

        return list(self._session.scalars(statement).all())
