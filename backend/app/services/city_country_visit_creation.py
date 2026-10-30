"""Atomic creation of explicitly associated country and city visits."""

from uuid import UUID

from sqlalchemy.orm import Session

from app.domain.city_country_visit_association import (
    VisitDateRange,
    validate_city_country_association,
)
from app.models.city import City
from app.models.city_visit import CityVisit
from app.repositories.city_visits import CityVisitRepository
from app.repositories.country_visits import CountryVisitRepository
from app.schemas.city_visits import CityVisitCreate


def create_city_with_country_visit(
    *,
    session: Session,
    user_id: UUID,
    city: City,
    payload: CityVisitCreate,
) -> CityVisit:
    """Create a country visit and its city visit in one transaction."""

    country_data = payload.new_country_visit

    if country_data is None:
        raise ValueError("New country visit data is required.")

    validate_city_country_association(
        city_country_code=city.country_code,
        country_visit_country_code=city.country_code,
        city_dates=VisitDateRange(
            started_on=payload.started_on,
            started_on_precision=payload.started_on_precision,
            ended_on=payload.ended_on,
            ended_on_precision=payload.ended_on_precision,
        ),
        country_dates=VisitDateRange(
            started_on=country_data.started_on,
            started_on_precision=country_data.started_on_precision,
            ended_on=country_data.ended_on,
            ended_on_precision=country_data.ended_on_precision,
        ),
    )

    country_repository = CountryVisitRepository(session)
    city_repository = CityVisitRepository(session)

    try:
        country_visit = country_repository.create(
            user_id=user_id,
            country_code=city.country_code,
            started_on=country_data.started_on,
            started_on_precision=country_data.started_on_precision,
            ended_on=country_data.ended_on,
            ended_on_precision=country_data.ended_on_precision,
            commit=False,
        )

        city_visit = city_repository.create(
            user_id=user_id,
            city_id=city.id,
            country_visit_id=country_visit.id,
            started_on=payload.started_on,
            started_on_precision=payload.started_on_precision,
            ended_on=payload.ended_on,
            ended_on_precision=payload.ended_on_precision,
            commit=False,
        )

        session.commit()
        session.refresh(city_visit)

        return city_visit

    except Exception:
        session.rollback()
        raise
