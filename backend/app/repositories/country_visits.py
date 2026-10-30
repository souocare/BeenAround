"""Country visit database queries."""

from datetime import date
from uuid import UUID

from sqlalchemy import delete, select, update
from sqlalchemy.orm import Session

from app.domain.city_country_visit_association import VisitDateRange
from app.domain.visit_dates import DatePrecision
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
        started_on_precision: DatePrecision | None,
        ended_on_precision: DatePrecision | None,
        commit: bool = True,
    ) -> CountryVisit:
        """Persist a new country visit."""

        visit = CountryVisit(
            user_id=user_id,
            country_code=country_code,
            started_on=started_on,
            started_on_precision=started_on_precision,
            ended_on=ended_on,
            ended_on_precision=ended_on_precision,
        )

        self._session.add(visit)

        if commit:
            self._session.commit()
            self._session.refresh(visit)
        else:
            self._session.flush()

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
        started_on_precision: DatePrecision | None,
        ended_on_precision: DatePrecision | None,
    ) -> CountryVisit:
        """Persist validated changes to an existing country visit."""

        visit.country_code = country_code
        visit.started_on = started_on
        visit.started_on_precision = started_on_precision
        visit.ended_on = ended_on
        visit.ended_on_precision = ended_on_precision

        self._session.commit()
        self._session.refresh(visit)

        return visit

    def update_dates_if_unchanged(
        self,
        *,
        visit_id: UUID,
        user_id: UUID,
        expected: VisitDateRange,
        proposed: VisitDateRange,
    ) -> bool:
        """Update dates only when the country visit still matches the expected state.

        The caller owns the transaction. This method never commits.
        """

        statement = (
            update(CountryVisit)
            .where(
                CountryVisit.id == visit_id,
                CountryVisit.user_id == user_id,
                CountryVisit.started_on == expected.started_on,
                CountryVisit.started_on_precision == expected.started_on_precision,
                CountryVisit.ended_on == expected.ended_on,
                CountryVisit.ended_on_precision == expected.ended_on_precision,
            )
            .values(
                started_on=proposed.started_on,
                started_on_precision=proposed.started_on_precision,
                ended_on=proposed.ended_on,
                ended_on_precision=proposed.ended_on_precision,
            )
            .execution_options(synchronize_session=False)
        )

        result = self._session.execute(statement)

        return result.rowcount == 1

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
