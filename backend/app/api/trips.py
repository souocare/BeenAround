"""Trip REST endpoints."""

from uuid import UUID

from fastapi import APIRouter, HTTPException, status
from sqlalchemy.engine import Engine

from app.api.dependencies import CurrentApiUser, DatabaseSession
from app.repositories.trips import TripRepository
from app.schemas.trips import (
    TripCreate,
    TripListResponse,
    TripResponse,
    TripUpdate,
)
from app.services.trips import (
    InvalidTripDates,
    TripNotFound,
    create_trip,
    delete_trip,
    update_trip,
)


router = APIRouter(
    prefix="/trips",
    tags=["Trips"],
)


def get_write_engine(session: DatabaseSession) -> Engine:
    """Resolve the configured engine for Trip writes."""

    bind = session.get_bind()

    if not isinstance(bind, Engine):
        raise RuntimeError("Trip write operations require an engine-bound session.")

    return bind


@router.get(
    "",
    response_model=TripListResponse,
)
def list_trips(
    user: CurrentApiUser,
    session: DatabaseSession,
) -> TripListResponse:
    """List the authenticated user's Trips."""

    repository = TripRepository(session)

    trips = repository.list_for_user(user.id)

    return TripListResponse(
        items=[TripResponse.model_validate(trip) for trip in trips],
        total=len(trips),
    )


@router.get(
    "/{trip_id}",
    response_model=TripResponse,
)
def get_trip(
    trip_id: UUID,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> TripResponse:
    """Retrieve an owned Trip."""

    repository = TripRepository(session)

    trip = repository.get_for_user(
        trip_id=trip_id,
        user_id=user.id,
    )

    if trip is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trip not found.",
        )

    return TripResponse.model_validate(trip)


@router.post(
    "",
    response_model=TripResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_trip_endpoint(
    payload: TripCreate,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> TripResponse:
    """Create a Trip belonging to the authenticated user."""

    trip = create_trip(
        engine=get_write_engine(session),
        user_id=user.id,
        payload=payload,
    )

    return TripResponse.model_validate(trip)


@router.patch(
    "/{trip_id}",
    response_model=TripResponse,
)
def update_trip_endpoint(
    trip_id: UUID,
    payload: TripUpdate,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> TripResponse:
    """Update an owned Trip."""

    try:
        trip = update_trip(
            engine=get_write_engine(session),
            user_id=user.id,
            trip_id=trip_id,
            payload=payload,
        )

    except TripNotFound as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(error),
        ) from error

    except InvalidTripDates as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=str(error),
        ) from error

    return TripResponse.model_validate(trip)


@router.delete(
    "/{trip_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_trip_endpoint(
    trip_id: UUID,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> None:
    """Delete an owned Trip."""

    try:
        delete_trip(
            engine=get_write_engine(session),
            user_id=user.id,
            trip_id=trip_id,
        )

    except TripNotFound as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(error),
        ) from error
