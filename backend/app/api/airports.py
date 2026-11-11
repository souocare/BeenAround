"""Airport catalog REST endpoints."""

from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, status

from app.api.dependencies import CurrentApiUser, DatabaseSession
from app.repositories.airports import AirportRepository
from app.schemas.airports import AirportListResponse, AirportResponse


router = APIRouter(
    prefix="/airports",
    tags=["Airports"],
)


@router.get(
    "",
    response_model=AirportListResponse,
)
def search_airports(
    user: CurrentApiUser,
    session: DatabaseSession,
    q: Annotated[str | None, Query(max_length=200)] = None,
    country_code: Annotated[
        str | None,
        Query(min_length=2, max_length=2),
    ] = None,
    scheduled_only: bool = False,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> AirportListResponse:
    """Search the local shared airport catalog."""

    normalized_query = q.strip() if q is not None else None

    normalized_country = country_code.strip().upper() if country_code is not None else None

    if not normalized_query and not normalized_country:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Provide q or country_code.",
        )

    repository = AirportRepository(session)

    rows, total = repository.search(
        query=normalized_query,
        country_code=normalized_country,
        scheduled_only=scheduled_only,
        limit=limit,
        offset=offset,
    )

    return AirportListResponse(
        items=[
            AirportResponse(
                id=airport.id,
                ident=airport.ident,
                iata_code=airport.iata_code,
                icao_code=airport.icao_code,
                name=airport.name,
                municipality=airport.municipality,
                source_country_code=airport.source_country_code,
                country_code=airport.country_code,
                country_name=country_name,
                latitude=airport.latitude,
                longitude=airport.longitude,
                type=airport.type,
                scheduled_service=airport.scheduled_service,
            )
            for airport, country_name in rows
        ],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get(
    "/{airport_id}",
    response_model=AirportResponse,
)
def get_airport(
    airport_id: int,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> AirportResponse:
    """Retrieve one airport by its catalog ID."""

    repository = AirportRepository(session)

    result = repository.get_with_country(airport_id)

    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Airport not found.",
        )

    airport, country_name = result

    return AirportResponse(
        id=airport.id,
        ident=airport.ident,
        iata_code=airport.iata_code,
        icao_code=airport.icao_code,
        name=airport.name,
        municipality=airport.municipality,
        source_country_code=airport.source_country_code,
        country_code=airport.country_code,
        country_name=country_name,
        latitude=airport.latitude,
        longitude=airport.longitude,
        type=airport.type,
        scheduled_service=airport.scheduled_service,
    )
