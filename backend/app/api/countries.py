"""Country catalog REST endpoints."""

from fastapi import APIRouter, HTTPException, status

from app.api.dependencies import CurrentApiUser, DatabaseSession
from app.repositories.countries import CountryRepository
from app.schemas.countries import CountryListResponse, CountryResponse
from app.repositories.trips import TripRepository
from app.schemas.trips import TripListResponse, TripResponse

router = APIRouter(
    prefix="/countries",
    tags=["Countries"],
)


@router.get(
    "",
    response_model=CountryListResponse,
)
def list_countries(
    user: CurrentApiUser,
    session: DatabaseSession,
) -> CountryListResponse:
    """Return the complete shared country catalog."""

    repository = CountryRepository(session)

    countries = repository.list_all()

    return CountryListResponse(
        items=[CountryResponse.model_validate(country) for country in countries],
        total=len(countries),
    )


@router.get(
    "/{code}",
    response_model=CountryResponse,
)
def get_country(
    code: str,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> CountryResponse:
    """Return a country by its ISO alpha-2 code."""

    normalized_code = code.strip().upper()

    repository = CountryRepository(session)

    country = repository.get_by_code(normalized_code)

    if country is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Country not found.",
        )

    return CountryResponse.model_validate(country)

@router.get(
    "/{code}/trips",
    response_model=TripListResponse,
)
def list_country_trips(
    code: str,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> TripListResponse:
    """List explicitly associated Trips for a country.

    Includes Trips associated through country visits or city visits.

    Returns only records belonging to the authenticated user.
    """

    normalized_code = code.strip().upper()

    country_repository = CountryRepository(session)

    country = country_repository.get_by_code(normalized_code)

    if country is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Country not found.",
        )

    trip_repository = TripRepository(session)

    trips = trip_repository.list_for_country(
        user_id=user.id,
        country_code=normalized_code,
    )

    return TripListResponse(
        items=[
            TripResponse.model_validate(trip)
            for trip in trips
        ],
        total=len(trips),
    )