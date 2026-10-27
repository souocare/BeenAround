"""City visit REST endpoints."""

from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from app.api.dependencies import CurrentApiUser, DatabaseSession
from app.domain.visit_dates import (
    DatePrecision,
    resolve_partial_visit_update,
)
from app.models.city import City
from app.models.city_visit import CityVisit
from app.models.country import Country
from app.repositories.city_visits import CityVisitRepository
from app.schemas.city_visits import (
    CityVisitCreate,
    CityVisitListResponse,
    CityVisitResponse,
    CityVisitUpdate,
)


router = APIRouter(
    prefix="/city-visits",
    tags=["City Visits"],
)


def serialize_visit(
    visit: CityVisit,
    *,
    city_name: str,
    country_code: str,
    country_name: str,
) -> CityVisitResponse:
    """Build a city visit response with catalog details."""

    return CityVisitResponse(
        id=visit.id,
        city_id=visit.city_id,
        city_name=city_name,
        country_code=country_code,
        country_name=country_name,
        started_on=visit.started_on,
        started_on_precision=visit.started_on_precision,
        ended_on=visit.ended_on,
        ended_on_precision=visit.ended_on_precision,
        created_at=visit.created_at,
        updated_at=visit.updated_at,
    )


def serialize_visit_with_city(
    visit: CityVisit,
    city: City,
    country: Country,
) -> CityVisitResponse:
    """Build a city visit response using its catalog records."""

    return serialize_visit(
        visit,
        city_name=city.name,
        country_code=city.country_code,
        country_name=country.name,
    )


@router.get(
    "",
    response_model=CityVisitListResponse,
)
def list_city_visits(
    user: CurrentApiUser,
    session: DatabaseSession,
) -> CityVisitListResponse:
    """List the authenticated user's city visits."""

    repository = CityVisitRepository(session)

    rows = repository.list_for_user(user.id)

    return CityVisitListResponse(
        items=[
            serialize_visit(
                visit,
                city_name=city_name,
                country_code=country_code,
                country_name=country_name,
            )
            for visit, city_name, country_code, country_name in rows
        ],
        total=len(rows),
    )


@router.post(
    "",
    response_model=CityVisitResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_city_visit(
    payload: CityVisitCreate,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> CityVisitResponse:
    """Register a city visit for the authenticated user."""

    repository = CityVisitRepository(session)

    city = repository.get_city(payload.city_id)

    if city is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="City not found.",
        )

    country = session.get(Country, city.country_code)

    visit = repository.create(
        user_id=user.id,
        city_id=city.id,
        started_on=payload.started_on,
        started_on_precision=payload.started_on_precision,
        ended_on=payload.ended_on,
        ended_on_precision=payload.ended_on_precision,
    )

    return serialize_visit_with_city(visit, city, country)


@router.patch(
    "/{visit_id}",
    response_model=CityVisitResponse,
)
def update_city_visit(
    visit_id: UUID,
    payload: CityVisitUpdate,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> CityVisitResponse:
    """Update a city visit owned by the authenticated user."""

    repository = CityVisitRepository(session)

    visit = repository.get_for_user(
        visit_id=visit_id,
        user_id=user.id,
    )

    if visit is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="City visit not found.",
        )

    changes = payload.model_dump(exclude_unset=True)

    city_id = changes.get("city_id", visit.city_id)

    try:
        (
            started_on,
            started_on_precision,
            ended_on,
            ended_on_precision,
        ) = resolve_partial_visit_update(
            current_started_on=visit.started_on,
            current_started_on_precision=(
                DatePrecision(visit.started_on_precision)
                if visit.started_on_precision is not None
                else None
            ),
            current_ended_on=visit.ended_on,
            current_ended_on_precision=(
                DatePrecision(visit.ended_on_precision)
                if visit.ended_on_precision is not None
                else None
            ),
            changes=changes,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(error),
        ) from error

    city = repository.get_city(city_id)

    if city is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="City not found.",
        )

    country = session.get(Country, city.country_code)

    updated = repository.update(
        visit=visit,
        city_id=city.id,
        started_on=started_on,
        started_on_precision=started_on_precision,
        ended_on=ended_on,
        ended_on_precision=ended_on_precision,
    )

    return serialize_visit_with_city(updated, city, country)


@router.delete(
    "/{visit_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_city_visit(
    visit_id: UUID,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> None:
    """Delete a visit owned by the authenticated user."""

    repository = CityVisitRepository(session)

    deleted = repository.delete_for_user(
        visit_id=visit_id,
        user_id=user.id,
    )

    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="City visit not found.",
        )
