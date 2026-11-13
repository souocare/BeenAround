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
    FlightDetailResponse,
    FlightLocalTimeResponse,
    FlightTimingResponse,
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
from app.models.airport import Airport
from app.services.flight_time import calculate_flight_timing


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

def _build_flight_timing_response(
    *,
    flight: FlightResponse,
    session: DatabaseSession,
) -> FlightTimingResponse:
    """Calculate timing from the flight's airport-local schedules."""

    departure_airport = session.get(
        Airport,
        flight.departure_airport_id,
    )

    arrival_airport = session.get(
        Airport,
        flight.arrival_airport_id,
    )

    timing = calculate_flight_timing(
        departure_on=flight.departure_on.isoformat(),
        departure_time=(
            flight.departure_time.isoformat()
            if flight.departure_time is not None
            else None
        ),
        departure_timezone_id=(
            departure_airport.timezone_id
            if departure_airport is not None
            else None
        ),
        arrival_on=(
            flight.arrival_on.isoformat()
            if flight.arrival_on is not None
            else None
        ),
        arrival_time=(
            flight.arrival_time.isoformat()
            if flight.arrival_time is not None
            else None
        ),
        arrival_timezone_id=(
            arrival_airport.timezone_id
            if arrival_airport is not None
            else None
        ),
    )

    return FlightTimingResponse(
        departure=FlightLocalTimeResponse(
            status=timing.departure.status,
            utc_offset_minutes=timing.departure.utc_offset_minutes,
        ),
        arrival=FlightLocalTimeResponse(
            status=timing.arrival.status,
            utc_offset_minutes=timing.arrival.utc_offset_minutes,
        ),
        duration_minutes=timing.duration_minutes,
    )

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
    response_model=FlightDetailResponse,
)
def get_my_flight(
    flight_id: UUID,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> FlightDetailResponse:
    """Retrieve one owned flight with calculated timing information."""

    try:
        flight = get_flight(
            engine=get_write_engine(session),
            user_id=user.id,
            flight_id=flight_id,
        )
    except FlightNotFound as error:
        _raise_flight_error(error)

    # Ownership has already been verified by get_flight().
    # Never resolve personal flight details before authorization.
    flight_response = FlightResponse.model_validate(flight)

    timing_response = _build_flight_timing_response(
        flight=flight_response,
        session=session,
    )

    return FlightDetailResponse(
        **flight_response.model_dump(),
        timing=timing_response,
    )


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
