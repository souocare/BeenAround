"""Country visit REST endpoints."""

from fastapi import APIRouter

from app.api.dependencies import CurrentApiUser, DatabaseSession
from app.repositories.country_visits import CountryVisitRepository
from app.schemas.country_visits import (
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
