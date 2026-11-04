"""City catalog REST endpoints."""

from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, status
from typing import Literal

from app.api.dependencies import CurrentApiUser, DatabaseSession
from app.repositories.cities import CityRepository
from app.schemas.cities import (
    CityListResponse,
    CityResolveRequest,
    CityResolveResponse,
    CityResponse,
    CountryCityCountListResponse,
    CountryCityCountResponse,
)


router = APIRouter(
    prefix="/cities",
    tags=["Cities"],
)


@router.get(
    "",
    response_model=CityListResponse,
)
def search_cities(
    user: CurrentApiUser,
    session: DatabaseSession,
    q: Annotated[str | None, Query(max_length=200)] = None,
    country_code: Annotated[str | None, Query(min_length=2, max_length=2)] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
    sort: Literal["population", "name"] = "population",
) -> CityListResponse:
    """Search the shared city catalog."""

    normalized_query = q.strip() if q is not None else None
    normalized_country = country_code.strip().upper() if country_code is not None else None

    if not normalized_query and not normalized_country:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Provide q or country_code.",
        )

    repository = CityRepository(session)

    rows, total = repository.search(
        query=normalized_query,
        country_code=normalized_country,
        limit=limit,
        offset=offset,
        sort=sort,
    )

    return CityListResponse(
        items=[
            CityResponse(
                id=city.id,
                name=city.name,
                ascii_name=city.ascii_name,
                country_code=city.country_code,
                country_name=country_name,
                latitude=city.latitude,
                longitude=city.longitude,
                population=city.population,
                feature_code=city.feature_code,
            )
            for city, country_name in rows
        ],
        total=total,
        limit=limit,
        offset=offset,
        sort=sort,
    )


@router.get(
    "/countries",
    response_model=CountryCityCountListResponse,
)
def list_country_city_counts(
    user: CurrentApiUser,
    session: DatabaseSession,
) -> CountryCityCountListResponse:
    """List catalog countries with their city counts."""

    repository = CityRepository(session)

    rows = repository.list_country_city_counts()

    return CountryCityCountListResponse(
        items=[
            CountryCityCountResponse(
                country_code=country_code,
                country_name=country_name,
                city_count=city_count,
            )
            for country_code, country_name, city_count in rows
        ]
    )


@router.post(
    "/resolve",
    response_model=CityResolveResponse,
)
def resolve_cities(
    payload: CityResolveRequest,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> CityResolveResponse:
    """Resolve city catalog entries by their geographic IDs."""

    repository = CityRepository(session)

    rows = repository.resolve_by_ids(
        city_ids=payload.city_ids,
    )

    return CityResolveResponse(
        items=[
            CityResponse(
                id=city.id,
                name=city.name,
                ascii_name=city.ascii_name,
                country_code=city.country_code,
                country_name=country_name,
                latitude=city.latitude,
                longitude=city.longitude,
                population=city.population,
                feature_code=city.feature_code,
            )
            for city, country_name in rows
        ],
    )
