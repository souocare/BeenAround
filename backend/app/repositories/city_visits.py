"""City visit database queries."""

from datetime import date
from uuid import UUID

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

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

    def get_city(self, city_id: int) -> City | None:
        """Retrieve a city from the shared catalog."""

        return self._session.get(City, city_id)

    def create(
        self,
        *,
        user_id: UUID,
        city_id: int,
        started_on: date | None,
        ended_on: date | None,
    ) -> CityVisit:
        """Persist a new city visit."""

        visit = CityVisit(
            user_id=user_id,
            city_id=city_id,
            started_on=started_on,
            ended_on=ended_on,
        )

        self._session.add(visit)
        self._session.commit()
        self._session.refresh(visit)

        return visit

    def update(
        self,
        *,
        visit: CityVisit,
        city_id: int,
        started_on: date | None,
        ended_on: date | None,
    ) -> CityVisit:
        """Persist validated changes to an existing visit."""

        visit.city_id = city_id
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
        """Delete a visit only when owned by the given user."""

        statement = delete(CityVisit).where(
            CityVisit.id == visit_id,
            CityVisit.user_id == user_id,
        )

        result = self._session.execute(statement)
        deleted = result.rowcount == 1

        self._session.commit()

        return deleted
