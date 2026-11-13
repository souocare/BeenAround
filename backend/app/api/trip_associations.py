"""REST endpoints for Trip visit associations."""

from uuid import UUID

from fastapi import APIRouter, HTTPException, Response, status

from app.api.dependencies import CurrentApiUser, DatabaseSession
from app.api.trips import get_write_engine

from app.schemas.city_visits import (
    CityVisitListResponse,
    CityVisitResponse,
)
from app.schemas.country_visits import (
    CountryVisitListResponse,
    CountryVisitResponse,
)
from app.schemas.trip_associations import (
    TripCityVisitCreate,
    TripCountryVisitCreate,
    TripVisitAssociationResponse,
    TripFlightCreate,
    TripFlightAssociationResponse,
    TripFlightListResponse,
)

from app.services.trip_associations import (
    TripAssociationNotFound,
    VisitNotFound,
    add_trip_city_visit,
    add_trip_country_visit,
    list_trip_city_visits,
    list_trip_country_visits,
    remove_trip_city_visit,
    remove_trip_country_visit,
    FlightNotFound,
    add_trip_flight,
    list_trip_flights,
    remove_trip_flight,
)
from app.services.trips import TripNotFound
from app.schemas.flights import FlightResponse

router = APIRouter(
    prefix="/trips",
    tags=["Trip Associations"],
)


def _raise_not_found(error: Exception) -> None:
    """Hide whether an inaccessible resource exists."""

    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=str(error),
    ) from error


# ---------------------------------------------------------
# Country visits
# ---------------------------------------------------------


@router.get(
    "/{trip_id}/country-visits",
    response_model=CountryVisitListResponse,
)
def get_trip_country_visits(
    trip_id: UUID,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> CountryVisitListResponse:
    """List country visits explicitly associated with a Trip."""

    try:
        visits = list_trip_country_visits(
            session=session,
            user_id=user.id,
            trip_id=trip_id,
        )

    except TripNotFound as error:
        _raise_not_found(error)

    return CountryVisitListResponse(
        items=[CountryVisitResponse.model_validate(visit) for visit in visits],
        total=len(visits),
    )


@router.post(
    "/{trip_id}/country-visits",
    response_model=TripVisitAssociationResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_trip_country_visit_association(
    trip_id: UUID,
    payload: TripCountryVisitCreate,
    response: Response,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> TripVisitAssociationResponse:
    """Associate an existing country visit with an owned Trip."""

    try:
        created = add_trip_country_visit(
            engine=get_write_engine(session),
            user_id=user.id,
            trip_id=trip_id,
            visit_id=payload.country_visit_id,
        )

    except (TripNotFound, VisitNotFound) as error:
        _raise_not_found(error)

    if not created:
        response.status_code = status.HTTP_200_OK

    return TripVisitAssociationResponse(
        trip_id=trip_id,
        visit_id=payload.country_visit_id,
    )


@router.delete(
    "/{trip_id}/country-visits/{visit_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_trip_country_visit_association(
    trip_id: UUID,
    visit_id: UUID,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> None:
    """Remove a country visit association without deleting the visit."""

    try:
        remove_trip_country_visit(
            engine=get_write_engine(session),
            user_id=user.id,
            trip_id=trip_id,
            visit_id=visit_id,
        )

    except (
        TripNotFound,
        VisitNotFound,
        TripAssociationNotFound,
    ) as error:
        _raise_not_found(error)


# ---------------------------------------------------------
# City visits
# ---------------------------------------------------------


@router.get(
    "/{trip_id}/city-visits",
    response_model=CityVisitListResponse,
)
def get_trip_city_visits(
    trip_id: UUID,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> CityVisitListResponse:
    """List city visits explicitly associated with a Trip."""

    try:
        rows = list_trip_city_visits(
            session=session,
            user_id=user.id,
            trip_id=trip_id,
        )

    except TripNotFound as error:
        _raise_not_found(error)

    items = [
        CityVisitResponse(
            id=visit.id,
            city_id=visit.city_id,
            city_name=city_name,
            country_code=country_code,
            country_name=country_name,
            country_visit_id=visit.country_visit_id,
            started_on=visit.started_on,
            ended_on=visit.ended_on,
            started_on_precision=visit.started_on_precision,
            ended_on_precision=visit.ended_on_precision,
            created_at=visit.created_at,
            updated_at=visit.updated_at,
        )
        for visit, city_name, country_code, country_name in rows
    ]

    return CityVisitListResponse(
        items=items,
        total=len(items),
    )


@router.post(
    "/{trip_id}/city-visits",
    response_model=TripVisitAssociationResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_trip_city_visit_association(
    trip_id: UUID,
    payload: TripCityVisitCreate,
    response: Response,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> TripVisitAssociationResponse:
    """Associate an existing city visit with an owned Trip."""

    try:
        created = add_trip_city_visit(
            engine=get_write_engine(session),
            user_id=user.id,
            trip_id=trip_id,
            visit_id=payload.city_visit_id,
        )

    except (TripNotFound, VisitNotFound) as error:
        _raise_not_found(error)

    if not created:
        response.status_code = status.HTTP_200_OK

    return TripVisitAssociationResponse(
        trip_id=trip_id,
        visit_id=payload.city_visit_id,
    )


@router.delete(
    "/{trip_id}/city-visits/{visit_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_trip_city_visit_association(
    trip_id: UUID,
    visit_id: UUID,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> None:
    """Remove a city visit association without deleting the visit."""

    try:
        remove_trip_city_visit(
            engine=get_write_engine(session),
            user_id=user.id,
            trip_id=trip_id,
            visit_id=visit_id,
        )

    except (
        TripNotFound,
        VisitNotFound,
        TripAssociationNotFound,
    ) as error:
        _raise_not_found(error)


# ---------------------------------------------------------
# Flights
# ---------------------------------------------------------


@router.get(
    "/{trip_id}/flights",
    response_model=TripFlightListResponse,
)
def get_trip_flights(
    trip_id: UUID,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> TripFlightListResponse:
    """List flights explicitly associated with an owned Trip."""

    try:
        flights = list_trip_flights(
            session=session,
            user_id=user.id,
            trip_id=trip_id,
        )

    except TripNotFound as error:
        _raise_not_found(error)

    return TripFlightListResponse(
        items=[FlightResponse.model_validate(flight) for flight in flights],
        total=len(flights),
    )


@router.post(
    "/{trip_id}/flights",
    response_model=TripFlightAssociationResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_trip_flight_association(
    trip_id: UUID,
    payload: TripFlightCreate,
    response: Response,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> TripFlightAssociationResponse:
    """Associate an existing owned flight with an owned Trip."""

    try:
        created = add_trip_flight(
            engine=get_write_engine(session),
            user_id=user.id,
            trip_id=trip_id,
            flight_id=payload.flight_id,
        )

    except (TripNotFound, FlightNotFound) as error:
        _raise_not_found(error)

    if not created:
        response.status_code = status.HTTP_200_OK

    return TripFlightAssociationResponse(
        trip_id=trip_id,
        flight_id=payload.flight_id,
    )


@router.delete(
    "/{trip_id}/flights/{flight_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_trip_flight_association(
    trip_id: UUID,
    flight_id: UUID,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> None:
    """Remove a Trip–Flight association without deleting the flight."""

    try:
        remove_trip_flight(
            engine=get_write_engine(session),
            user_id=user.id,
            trip_id=trip_id,
            flight_id=flight_id,
        )

    except (
        TripNotFound,
        FlightNotFound,
        TripAssociationNotFound,
    ) as error:
        _raise_not_found(error)
