"""City visit database queries."""

from datetime import date
from uuid import UUID

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.domain.visit_dates import DatePrecision
from app.models.city import City
from app.models.city_visit import CityVisit
from app.models.country import Country

type CityVisitRow = tuple[CityVisit, str, str, str]


class CityVisitRepository:
    """Persistence operations for city visits."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def _with_city_details(self):
        return (
            select(
                CityVisit,
                City.name,
                City.country_code,
                Country.name,
            )
            .join(City, City.id == CityVisit.city_id)
            .join(Country, Country.code == City.country_code)
        )

    def list_for_user(self, user_id: UUID) -> list[CityVisitRow]:
        statement = (
            self._with_city_details()
            .where(CityVisit.user_id == user_id)
            .order_by(
                CityVisit.created_at.desc(),
                CityVisit.id.desc(),
            )
        )

        return [
            (visit, city_name, country_code, country_name)
            for visit, city_name, country_code, country_name in self._session.execute(statement)
        ]

    def get_for_user(
        self,
        *,
        visit_id: UUID,
        user_id: UUID,
    ) -> CityVisit | None:
        """Find a city visit only when owned by the given user."""

        return self._session.scalar(
            select(CityVisit).where(
                CityVisit.id == visit_id,
                CityVisit.user_id == user_id,
            )
        )

    def list_for_country_visit(
        self,
        *,
        country_visit_id: UUID,
        user_id: UUID,
    ) -> list[tuple[CityVisit, str]]:
        """Return city visits linked to a country visit, including country codes."""

        statement = (
            select(CityVisit, City.country_code)
            .join(City, City.id == CityVisit.city_id)
            .where(
                CityVisit.country_visit_id == country_visit_id,
                CityVisit.user_id == user_id,
            )
            .order_by(CityVisit.id)
        )

        return list(self._session.execute(statement).all())

    def get_city(self, city_id: int) -> City | None:
        """Retrieve a city from the shared catalog."""

        return self._session.get(City, city_id)

    def create(
        self,
        *,
        user_id: UUID,
        city_id: int,
        started_on: date | None,
        started_on_precision: DatePrecision | None,
        ended_on: date | None,
        ended_on_precision: DatePrecision | None,
        country_visit_id: UUID | None = None,
        commit: bool = True,
    ) -> CityVisit:
        """Persist a new city visit with an optional country visit association."""

        visit = CityVisit(
            user_id=user_id,
            city_id=city_id,
            country_visit_id=country_visit_id,
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

    def update(
        self,
        *,
        visit: CityVisit,
        city_id: int,
        started_on: date | None,
        started_on_precision: DatePrecision | None,
        ended_on: date | None,
        ended_on_precision: DatePrecision | None,
        country_visit_id: UUID | None,
        commit: bool = True,
    ) -> CityVisit:
        """Persist validated changes to an existing city visit."""

        visit.city_id = city_id
        visit.country_visit_id = country_visit_id
        visit.started_on = started_on
        visit.started_on_precision = started_on_precision
        visit.ended_on = ended_on
        visit.ended_on_precision = ended_on_precision

        if commit:
            self._session.commit()
            self._session.refresh(visit)
        else:
            self._session.flush()

        return visit

    def delete_for_user(
        self,
        *,
        visit_id: UUID,
        user_id: UUID,
    ) -> bool:
        """Delete a visit only when owned by the given user."""

        statement = delete(CityVisit).where(
            CityVisit.id == visit_id,
            CityVisit.user_id == user_id,
        )

        result = self._session.execute(statement)
        deleted = result.rowcount == 1

        self._session.commit()

        return deleted
