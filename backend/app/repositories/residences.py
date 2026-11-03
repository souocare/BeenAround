"""Historical residence database queries."""

from datetime import date
from uuid import UUID

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.domain.visit_dates import DatePrecision
from app.models.city import City
from app.models.residence import Residence
from app.models.country import Country


class ResidenceRepository:
    """Persistence operations for historical residences."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def list_for_user(self, user_id: UUID) -> list[Residence]:
        """Return only residences belonging to the authenticated user."""

        statement = (
            select(Residence)
            .where(Residence.user_id == user_id)
            .order_by(
                Residence.created_at.desc(),
                Residence.id.desc(),
            )
        )

        return list(self._session.scalars(statement).all())

    def get_for_user(
        self,
        *,
        residence_id: UUID,
        user_id: UUID,
    ) -> Residence | None:
        """Retrieve a residence only when owned by the given user."""

        statement = select(Residence).where(
            Residence.id == residence_id,
            Residence.user_id == user_id,
        )

        return self._session.scalar(statement)

    def get_city(self, city_id: int) -> City | None:
        """Retrieve a city from the shared geographical catalog."""

        return self._session.get(City, city_id)

    def get_country(self, country_code: str) -> Country | None:
        """Retrieve a country from the shared geographical catalog."""

        return self._session.get(Country, country_code)

    def create(
        self,
        *,
        user_id: UUID,
        country_code: str,
        city_id: int | None,
        started_on: date,
        started_on_precision: DatePrecision,
        ended_on: date,
        ended_on_precision: DatePrecision,
        note: str | None = None,
        commit: bool = True,
    ) -> Residence:
        """Persist a new historical residence.

        When commit=False, the caller owns the transaction.
        """

        residence = Residence(
            user_id=user_id,
            country_code=country_code,
            city_id=city_id,
            started_on=started_on,
            started_on_precision=started_on_precision,
            ended_on=ended_on,
            ended_on_precision=ended_on_precision,
            note=note,
        )

        self._session.add(residence)

        if commit:
            self._session.commit()
            self._session.refresh(residence)
        else:
            self._session.flush()

        return residence

    def update(
        self,
        *,
        residence: Residence,
        country_code: str,
        city_id: int | None,
        started_on: date,
        started_on_precision: DatePrecision,
        ended_on: date,
        ended_on_precision: DatePrecision,
        note: str | None = None,
        commit: bool = True,
    ) -> Residence:
        """Persist validated changes to an existing residence.

        The application layer must verify ownership and domain rules
        before invoking this operation.
        """

        residence.country_code = country_code
        residence.city_id = city_id
        residence.started_on = started_on
        residence.started_on_precision = started_on_precision
        residence.ended_on = ended_on
        residence.ended_on_precision = ended_on_precision
        residence.note = note

        if commit:
            self._session.commit()
            self._session.refresh(residence)
        else:
            self._session.flush()

        return residence

    def delete_for_user(
        self,
        *,
        residence_id: UUID,
        user_id: UUID,
        commit: bool = True,
    ) -> bool:
        """Delete a residence only when owned by the given user."""

        statement = delete(Residence).where(
            Residence.id == residence_id,
            Residence.user_id == user_id,
        )

        result = self._session.execute(statement)
        deleted = result.rowcount == 1

        if commit:
            self._session.commit()

        return deleted
