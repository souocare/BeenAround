"""Authenticated airline catalog REST endpoints."""

from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, status

from app.api.dependencies import CurrentApiUser, DatabaseSession
from app.repositories.airlines import AirlineRepository
from app.schemas.airlines import AirlineListResponse, AirlineResponse


router = APIRouter(
    prefix="/airlines",
    tags=["Airlines"],
)


@router.get(
    "",
    response_model=AirlineListResponse,
)
def search_airlines(
    user: CurrentApiUser,
    session: DatabaseSession,
    q: Annotated[str, Query(min_length=1, max_length=200)],
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> AirlineListResponse:
    """Search the shared airline catalog."""

    normalized_query = q.strip()

    if not normalized_query:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Provide a non-empty search query.",
        )

    repository = AirlineRepository(session)

    airlines, total = repository.search(
        query=normalized_query,
        limit=limit,
        offset=offset,
    )

    return AirlineListResponse(
        items=[AirlineResponse.model_validate(airline) for airline in airlines],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get(
    "/{airline_id}",
    response_model=AirlineResponse,
)
def get_airline(
    airline_id: int,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> AirlineResponse:
    """Retrieve one airline by its catalog ID."""

    repository = AirlineRepository(session)

    airline = repository.get_by_id(airline_id)

    if airline is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Airline not found.",
        )

    return AirlineResponse.model_validate(airline)
