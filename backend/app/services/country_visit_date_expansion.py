"""Atomic application of confirmed country visit date expansions."""

from uuid import UUID

from sqlalchemy.orm import Session

from app.domain.city_country_visit_association import (
    VisitDateRange,
    propose_country_visit_date_expansion,
    validate_country_date_expansion_confirmation,
)
from app.domain.visit_dates import DatePrecision
from app.models.city import City
from app.models.city_visit import CityVisit
from app.models.country_visit import CountryVisit
from app.repositories.city_visits import CityVisitRepository
from app.repositories.country_visits import CountryVisitRepository
from app.schemas.city_visits import CountryDateExpansionConfirmation


class CountryVisitExpansionConflict(Exception):
    """The confirmed expansion is stale or cannot be applied."""


def country_visit_dates(visit: CountryVisit) -> VisitDateRange:
    """Return the current date range of a country visit."""

    return VisitDateRange(
        started_on=visit.started_on,
        started_on_precision=DatePrecision(visit.started_on_precision),
        ended_on=visit.ended_on,
        ended_on_precision=DatePrecision(visit.ended_on_precision),
    )


def confirmed_dates(
    confirmation: CountryDateExpansionConfirmation,
) -> tuple[VisitDateRange, VisitDateRange]:
    """Convert a confirmation into expected and proposed date ranges."""

    expected = VisitDateRange(
        started_on=confirmation.expected.started_on,
        started_on_precision=confirmation.expected.started_on_precision,
        ended_on=confirmation.expected.ended_on,
        ended_on_precision=confirmation.expected.ended_on_precision,
    )

    proposed = VisitDateRange(
        started_on=confirmation.proposed.started_on,
        started_on_precision=confirmation.proposed.started_on_precision,
        ended_on=confirmation.proposed.ended_on,
        ended_on_precision=confirmation.proposed.ended_on_precision,
    )

    return expected, proposed


def apply_confirmed_country_date_expansion(
    *,
    session: Session,
    user_id: UUID,
    country_visit: CountryVisit,
    city: City,
    city_dates: VisitDateRange,
    confirmation: CountryDateExpansionConfirmation,
    existing_city_visit: CityVisit | None = None,
) -> CityVisit:
    """Apply the exact confirmed expansion and save the city atomically."""

    if country_visit.user_id != user_id:
        raise CountryVisitExpansionConflict(
            "Country visit does not belong to the authenticated user."
        )

    current = country_visit_dates(country_visit)
    expected, confirmed = confirmed_dates(confirmation)

    try:
        proposal = propose_country_visit_date_expansion(
            city_country_code=city.country_code,
            country_visit_country_code=country_visit.country_code,
            city_dates=city_dates,
            country_dates=current,
        )

        validate_country_date_expansion_confirmation(
            current=current,
            expected=expected,
            proposed=proposal,
            confirmed=confirmed,
        )
    except ValueError as error:
        raise CountryVisitExpansionConflict(str(error)) from error

    assert proposal is not None

    country_repository = CountryVisitRepository(session)
    city_repository = CityVisitRepository(session)

    try:
        updated = country_repository.update_dates_if_unchanged(
            visit_id=country_visit.id,
            user_id=user_id,
            expected=expected,
            proposed=proposal.date_range,
        )

        if not updated:
            raise CountryVisitExpansionConflict(
                "Country visit dates changed before confirmation was applied."
            )

        if existing_city_visit is None:
            city_visit = city_repository.create(
                user_id=user_id,
                city_id=city.id,
                country_visit_id=country_visit.id,
                started_on=city_dates.started_on,
                started_on_precision=city_dates.started_on_precision,
                ended_on=city_dates.ended_on,
                ended_on_precision=city_dates.ended_on_precision,
                commit=False,
            )
        else:
            if existing_city_visit.user_id != user_id:
                raise CountryVisitExpansionConflict(
                    "City visit does not belong to the authenticated user."
                )

            city_visit = city_repository.update(
                visit=existing_city_visit,
                city_id=city.id,
                country_visit_id=country_visit.id,
                started_on=city_dates.started_on,
                started_on_precision=city_dates.started_on_precision,
                ended_on=city_dates.ended_on,
                ended_on_precision=city_dates.ended_on_precision,
                commit=False,
            )

        session.commit()
        session.expire_all()
        session.refresh(city_visit)

        return city_visit

    except Exception:
        session.rollback()
        raise
