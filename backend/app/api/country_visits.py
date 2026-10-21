"""Country visit REST endpoints."""

from fastapi import APIRouter, HTTPException, status

from app.api.dependencies import CurrentApiUser, DatabaseSession
from app.repositories.countries import CountryRepository
from app.repositories.country_visits import CountryVisitRepository
from app.schemas.country_visits import (
    CountryVisitCreate,
    CountryVisitListResponse,
    CountryVisitResponse,
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
        ended_on=payload.ended_on,
    )

    return CountryVisitResponse.model_validate(visit)
