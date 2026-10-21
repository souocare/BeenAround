"""Country visit database queries."""

from uuid import UUID
from datetime import date

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

    def create(
        self,
        *,
        user_id: UUID,
        country_code: str,
        started_on: date | None,
        ended_on: date | None,
    ) -> CountryVisit:
        """Persist a new country visit."""

        visit = CountryVisit(
            user_id=user_id,
            country_code=country_code,
            started_on=started_on,
            ended_on=ended_on,
        )

        self._session.add(visit)
        self._session.commit()
        self._session.refresh(visit)

        return visit
