"""Country visit REST endpoints."""

from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from app.api.dependencies import CurrentApiUser, DatabaseSession
from app.domain.city_country_visit_association import (
    VisitDateRange,
    validate_city_country_association,
)
from app.domain.visit_dates import (
    DatePrecision,
    resolve_partial_visit_update,
)
from app.repositories.city_visits import CityVisitRepository
from app.repositories.countries import CountryRepository
from app.repositories.country_visits import CountryVisitRepository
from app.schemas.country_visits import (
    CountryVisitCreate,
    CountryVisitListResponse,
    CountryVisitResponse,
    CountryVisitUpdate,
)

router = APIRouter(
    prefix="/country-visits",
    tags=["Country Visits"],
)


@router.get(
    "",
    response_model=CountryVisitListResponse,
)
def list_country_visits(
    user: CurrentApiUser,
    session: DatabaseSession,
) -> CountryVisitListResponse:
    """Return country visits belonging to the authenticated user."""

    repository = CountryVisitRepository(session)

    visits = repository.list_for_user(user.id)

    return CountryVisitListResponse(
        items=[CountryVisitResponse.model_validate(visit) for visit in visits],
        total=len(visits),
    )


@router.post(
    "",
    response_model=CountryVisitResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_country_visit(
    payload: CountryVisitCreate,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> CountryVisitResponse:
    """Register a country visit for the authenticated user."""

    country_repository = CountryRepository(session)

    country = country_repository.get_by_code(payload.country_code)

    if country is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Country not found.",
        )

    visit_repository = CountryVisitRepository(session)

    visit = visit_repository.create(
        user_id=user.id,
        country_code=country.code,
        started_on=payload.started_on,
        started_on_precision=payload.started_on_precision,
        ended_on=payload.ended_on,
        ended_on_precision=payload.ended_on_precision,
    )

    return CountryVisitResponse.model_validate(visit)


@router.patch(
    "/{visit_id}",
    response_model=CountryVisitResponse,
)
def update_country_visit(
    visit_id: UUID,
    payload: CountryVisitUpdate,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> CountryVisitResponse:
    """Update a country visit owned by the authenticated user."""

    repository = CountryVisitRepository(session)

    visit = repository.get_for_user(
        visit_id=visit_id,
        user_id=user.id,
    )

    if visit is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Country visit not found.",
        )

    changes = payload.model_dump(exclude_unset=True)

    country_code = changes.get(
        "country_code",
        visit.country_code,
    )

    try:
        (
            started_on,
            started_on_precision,
            ended_on,
            ended_on_precision,
        ) = resolve_partial_visit_update(
            current_started_on=visit.started_on,
            current_started_on_precision=(
                DatePrecision(visit.started_on_precision)
                if visit.started_on_precision is not None
                else None
            ),
            current_ended_on=visit.ended_on,
            current_ended_on_precision=(
                DatePrecision(visit.ended_on_precision)
                if visit.ended_on_precision is not None
                else None
            ),
            changes=changes,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(error),
        ) from error

    # Only look up the country when it is being changed.
    if "country_code" in changes:
        country = CountryRepository(session).get_by_code(country_code)

        if country is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Country not found.",
            )

        country_code = country.code

    # Validate all existing city associations against the proposed final state.
    associated_cities = CityVisitRepository(session).list_for_country_visit(
        country_visit_id=visit.id,
        user_id=user.id,
    )

    if associated_cities:
        proposed_country_dates = VisitDateRange(
            started_on=started_on,
            started_on_precision=started_on_precision,
            ended_on=ended_on,
            ended_on_precision=ended_on_precision,
        )

        for city_visit, city_country_code in associated_cities:
            city_dates = VisitDateRange(
                started_on=city_visit.started_on,
                started_on_precision=DatePrecision(city_visit.started_on_precision),
                ended_on=city_visit.ended_on,
                ended_on_precision=DatePrecision(city_visit.ended_on_precision),
            )

            try:
                validate_city_country_association(
                    city_country_code=city_country_code,
                    country_visit_country_code=country_code,
                    city_dates=city_dates,
                    country_dates=proposed_country_dates,
                )
            except ValueError as error:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=str(error),
                ) from error

    updated_visit = repository.update(
        visit=visit,
        country_code=country_code,
        started_on=started_on,
        started_on_precision=started_on_precision,
        ended_on=ended_on,
        ended_on_precision=ended_on_precision,
    )

    return CountryVisitResponse.model_validate(updated_visit)


@router.delete(
    "/{visit_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_country_visit(
    visit_id: UUID,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> None:
    """Delete a visit owned by the authenticated user."""

    repository = CountryVisitRepository(session)

    deleted = repository.delete_for_user(
        visit_id=visit_id,
        user_id=user.id,
    )

    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Country visit not found.",
        )
