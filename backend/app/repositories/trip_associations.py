"""Persistence operations for Trip visit associations."""

from uuid import UUID

from sqlalchemy import delete, select
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.orm import Session

from app.models.city import City
from app.models.city_visit import CityVisit
from app.models.country import Country
from app.models.country_visit import CountryVisit
from app.models.trip_city_visit import TripCityVisit
from app.models.trip_country_visit import TripCountryVisit


type CityVisitAssociationRow = tuple[
    CityVisit,
    str,
    str,
    str,
]


class TripAssociationRepository:
    """Manage links between Trips and independent visit records.

    The caller is responsible for authorization and transaction
    boundaries. This repository never commits.
    """

    def __init__(self, session: Session) -> None:
        self._session = session

    # ---------------------------------------------------------
    # Country visits
    # ---------------------------------------------------------

    def list_country_visits(
        self,
        *,
        trip_id: UUID,
    ) -> list[CountryVisit]:
        """Return country visits associated with a Trip."""

        statement = (
            select(CountryVisit)
            .join(
                TripCountryVisit,
                TripCountryVisit.country_visit_id == CountryVisit.id,
            )
            .where(
                TripCountryVisit.trip_id == trip_id,
            )
            .order_by(
                CountryVisit.created_at.desc(),
                CountryVisit.id.desc(),
            )
        )

        return list(self._session.scalars(statement).all())

    def add_country_visit(
        self,
        *,
        trip_id: UUID,
        visit_id: UUID,
    ) -> bool:
        """Insert a country visit association.

        Returns True when created and False when already present.

        The caller must verify ownership of both records.
        """

        statement = (
            sqlite_insert(TripCountryVisit)
            .values(
                trip_id=trip_id,
                country_visit_id=visit_id,
            )
            .on_conflict_do_nothing(
                index_elements=[
                    TripCountryVisit.trip_id,
                    TripCountryVisit.country_visit_id,
                ],
            )
        )

        result = self._session.execute(statement)

        return result.rowcount == 1

    def remove_country_visit(
        self,
        *,
        trip_id: UUID,
        visit_id: UUID,
    ) -> bool:
        """Remove only the association, preserving the visit."""

        statement = delete(TripCountryVisit).where(
            TripCountryVisit.trip_id == trip_id,
            TripCountryVisit.country_visit_id == visit_id,
        )

        result = self._session.execute(statement)

        return result.rowcount == 1

    # ---------------------------------------------------------
    # City visits
    # ---------------------------------------------------------

    def list_city_visits(
        self,
        *,
        trip_id: UUID,
    ) -> list[CityVisitAssociationRow]:
        """Return associated city visits with catalog details."""

        statement = (
            select(
                CityVisit,
                City.name,
                City.country_code,
                Country.name,
            )
            .join(
                TripCityVisit,
                TripCityVisit.city_visit_id == CityVisit.id,
            )
            .join(
                City,
                City.id == CityVisit.city_id,
            )
            .join(
                Country,
                Country.code == City.country_code,
            )
            .where(
                TripCityVisit.trip_id == trip_id,
            )
            .order_by(
                CityVisit.created_at.desc(),
                CityVisit.id.desc(),
            )
        )

        return [
            (
                visit,
                city_name,
                country_code,
                country_name,
            )
            for (
                visit,
                city_name,
                country_code,
                country_name,
            ) in self._session.execute(statement)
        ]

    def add_city_visit(
        self,
        *,
        trip_id: UUID,
        visit_id: UUID,
    ) -> bool:
        """Insert a city visit association if not already present."""

        statement = (
            sqlite_insert(TripCityVisit)
            .values(
                trip_id=trip_id,
                city_visit_id=visit_id,
            )
            .on_conflict_do_nothing(
                index_elements=[
                    TripCityVisit.trip_id,
                    TripCityVisit.city_visit_id,
                ],
            )
        )

        result = self._session.execute(statement)

        return result.rowcount == 1

    def remove_city_visit(
        self,
        *,
        trip_id: UUID,
        visit_id: UUID,
    ) -> bool:
        """Remove only the association, preserving the city visit."""

        statement = delete(TripCityVisit).where(
            TripCityVisit.trip_id == trip_id,
            TripCityVisit.city_visit_id == visit_id,
        )

        result = self._session.execute(statement)

        return result.rowcount == 1
