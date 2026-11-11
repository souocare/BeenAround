"""Authenticated REST endpoints for personal flights."""

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Response, status
from sqlalchemy.engine import Engine

from app.api.dependencies import CurrentApiUser, DatabaseSession
from app.domain.flights import FlightStatus
from app.schemas.flights import (
    FlightCreate,
    FlightListResponse,
    FlightResponse,
    FlightUpdate,
)
from app.services.flights import (
    AirlineNotFound,
    AirportNotFound,
    FlightNotFound,
    InvalidFlightData,
    create_flight,
    delete_flight,
    get_flight,
    list_flights,
    update_flight,
)


router = APIRouter(
    prefix="/flights",
    tags=["Flights"],
)


def get_write_engine(session: DatabaseSession) -> Engine:
    """Resolve the configured engine for Flight operations."""

    bind = session.get_bind()

    if not isinstance(bind, Engine):
        raise RuntimeError("Flight operations require an engine-bound session.")

    return bind


def _raise_flight_error(error: Exception) -> None:
    """Translate application errors into HTTP responses."""

    if isinstance(error, FlightNotFound):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Flight not found.",
        ) from error

    if isinstance(error, AirportNotFound):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="One or more referenced airports do not exist.",
        ) from error

    if isinstance(error, AirlineNotFound):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Referenced airline does not exist.",
        ) from error

    if isinstance(error, InvalidFlightData):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=str(error),
        ) from error

    raise error


@router.get(
    "",
    response_model=FlightListResponse,
)
def get_my_flights(
    user: CurrentApiUser,
    session: DatabaseSession,
    status_filter: Annotated[
        FlightStatus | None,
        Query(alias="status"),
    ] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> FlightListResponse:
    """List flights belonging to the authenticated user."""

    flights, total = list_flights(
        engine=get_write_engine(session),
        user_id=user.id,
        limit=limit,
        offset=offset,
        status=status_filter,
    )

    return FlightListResponse(
        items=[FlightResponse.model_validate(flight) for flight in flights],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.post(
    "",
    response_model=FlightResponse,
    status_code=status.HTTP_201_CREATED,
)
def register_flight(
    payload: FlightCreate,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> FlightResponse:
    """Register one flight segment for the authenticated user."""

    try:
        flight = create_flight(
            engine=get_write_engine(session),
            user_id=user.id,
            payload=payload,
        )
    except (
        AirportNotFound,
        AirlineNotFound,
        InvalidFlightData,
    ) as error:
        _raise_flight_error(error)

    return FlightResponse.model_validate(flight)


@router.get(
    "/{flight_id}",
    response_model=FlightResponse,
)
def get_my_flight(
    flight_id: UUID,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> FlightResponse:
    """Retrieve one flight belonging to the authenticated user."""

    try:
        flight = get_flight(
            engine=get_write_engine(session),
            user_id=user.id,
            flight_id=flight_id,
        )
    except FlightNotFound as error:
        _raise_flight_error(error)

    return FlightResponse.model_validate(flight)


@router.patch(
    "/{flight_id}",
    response_model=FlightResponse,
)
def edit_flight(
    flight_id: UUID,
    payload: FlightUpdate,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> FlightResponse:
    """Update an owned flight after validating its final state."""

    try:
        flight = update_flight(
            engine=get_write_engine(session),
            user_id=user.id,
            flight_id=flight_id,
            payload=payload,
        )
    except (
        FlightNotFound,
        AirportNotFound,
        AirlineNotFound,
        InvalidFlightData,
    ) as error:
        _raise_flight_error(error)

    return FlightResponse.model_validate(flight)


@router.delete(
    "/{flight_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def remove_flight(
    flight_id: UUID,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> Response:
    """Delete a flight belonging to the authenticated user."""

    try:
        delete_flight(
            engine=get_write_engine(session),
            user_id=user.id,
            flight_id=flight_id,
        )
    except FlightNotFound as error:
        _raise_flight_error(error)

    return Response(status_code=status.HTTP_204_NO_CONTENT)
