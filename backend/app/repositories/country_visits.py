"""Country visit database queries."""

from datetime import date
from uuid import UUID

from sqlalchemy import delete, select
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

    def get_for_user(
        self,
        *,
        visit_id: UUID,
        user_id: UUID,
    ) -> CountryVisit | None:
        """Find a country visit only when owned by the given user."""

        statement = select(CountryVisit).where(
            CountryVisit.id == visit_id,
            CountryVisit.user_id == user_id,
        )

        return self._session.scalar(statement)

    def update(
        self,
        *,
        visit: CountryVisit,
        country_code: str,
        started_on: date | None,
        ended_on: date | None,
    ) -> CountryVisit:
        """Persist validated changes to an existing country visit."""

        visit.country_code = country_code
        visit.started_on = started_on
        visit.ended_on = ended_on

        self._session.commit()
        self._session.refresh(visit)

        return visit

    def delete_for_user(
        self,
        *,
        visit_id: UUID,
        user_id: UUID,
    ) -> bool:
        """Delete a visit only if it belongs to the given user."""

        statement = delete(CountryVisit).where(
            CountryVisit.id == visit_id,
            CountryVisit.user_id == user_id,
        )

        result = self._session.execute(statement)
        deleted = result.rowcount == 1

        self._session.commit()

        return deleted
