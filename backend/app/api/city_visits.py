"""City visit REST endpoints."""

from uuid import UUID

from fastapi import APIRouter, HTTPException, status

from app.api.dependencies import CurrentApiUser, DatabaseSession
from app.domain.city_country_visit_association import (
    VisitDateRange,
    propose_country_visit_date_expansion,
    validate_city_country_association,
)
from app.domain.visit_dates import (
    DatePrecision,
    resolve_partial_visit_update,
)
from app.models.city import City
from app.models.city_visit import CityVisit
from app.models.country import Country
from app.models.country_visit import CountryVisit
from app.repositories.city_visits import CityVisitRepository
from app.repositories.country_visits import CountryVisitRepository
from app.schemas.city_visits import (
    CityVisitCreate,
    CityVisitListResponse,
    CityVisitResponse,
    CityVisitUpdate,
    CountryDateExpansionConfirmation,
    CountryVisitDateState,
)
from app.services.city_country_visit_creation import (
    create_city_with_country_visit,
)
from app.services.country_visit_date_expansion import (
    CountryVisitExpansionConflict,
    apply_confirmed_country_date_expansion,
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
        country_visit_id=visit.country_visit_id,
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


def country_visit_date_range(visit: CountryVisit) -> VisitDateRange:
    """Read the date range of an existing country visit."""

    return VisitDateRange(
        started_on=visit.started_on,
        started_on_precision=DatePrecision(visit.started_on_precision),
        ended_on=visit.ended_on,
        ended_on_precision=DatePrecision(visit.ended_on_precision),
    )


def date_state_payload(dates: VisitDateRange) -> dict:
    """Serialize a visit date range for an API conflict response."""

    return CountryVisitDateState(
        started_on=dates.started_on,
        started_on_precision=dates.started_on_precision,
        ended_on=dates.ended_on,
        ended_on_precision=dates.ended_on_precision,
    ).model_dump(mode="json")


def check_country_visit_association(
    *,
    country_visit: CountryVisit,
    city_country_code: str,
    city_dates: VisitDateRange,
    confirmation: CountryDateExpansionConfirmation | None,
) -> None:
    """Check an association and report expansions requiring confirmation.

    This step never modifies country visit dates.
    """

    current_dates = country_visit_date_range(country_visit)

    try:
        proposal = propose_country_visit_date_expansion(
            city_country_code=city_country_code,
            country_visit_country_code=country_visit.country_code,
            city_dates=city_dates,
            country_dates=current_dates,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(error),
        ) from error

    if proposal is None:
        if confirmation is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "COUNTRY_VISIT_DATE_EXPANSION_STALE",
                    "message": "Country visit date expansion is no longer required.",
                },
            )

        validate_city_country_association(
            city_country_code=city_country_code,
            country_visit_country_code=country_visit.country_code,
            city_dates=city_dates,
            country_dates=current_dates,
        )
        return

    # A confirmation cannot yet be applied in this implementation step.
    # The next step adds an atomic, conditional update.
    if confirmation is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "COUNTRY_VISIT_DATE_EXPANSION_NOT_APPLIED",
                "message": "Country visit date expansion has not been applied.",
            },
        )

    raise HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail={
            "code": "COUNTRY_VISIT_DATE_EXPANSION_REQUIRED",
            "message": ("Country visit dates must be expanded to include the city visit."),
            "country_visit_id": str(country_visit.id),
            "current": date_state_payload(current_dates),
            "proposed": date_state_payload(proposal.date_range),
        },
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
    """Register a city visit with an optional explicit country association."""

    repository = CityVisitRepository(session)

    city = repository.get_city(payload.city_id)

    if city is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="City not found.",
        )

    country = session.get(Country, city.country_code)

    # Option 1: Create a new country visit and city atomically.
    if payload.new_country_visit is not None:
        try:
            visit = create_city_with_country_visit(
                session=session,
                user_id=user.id,
                city=city,
                payload=payload,
            )
        except ValueError as error:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=str(error),
            ) from error

        return serialize_visit_with_city(visit, city, country)

    # Option 2: Associate with an existing country visit.
    if payload.country_visit_id is not None:
        country_visit = CountryVisitRepository(session).get_for_user(
            visit_id=payload.country_visit_id,
            user_id=user.id,
        )

        if country_visit is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Country visit not found.",
            )

        city_dates = VisitDateRange(
            started_on=payload.started_on,
            started_on_precision=payload.started_on_precision,
            ended_on=payload.ended_on,
            ended_on_precision=payload.ended_on_precision,
        )

        # Geographic compatibility is never resolved by expanding dates.
        if city.country_code != country_visit.country_code:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=("City and country visit must belong to the same country."),
            )

        # A previously presented expansion was explicitly confirmed.
        if payload.country_date_expansion is not None:
            try:
                visit = apply_confirmed_country_date_expansion(
                    session=session,
                    user_id=user.id,
                    country_visit=country_visit,
                    city=city,
                    city_dates=city_dates,
                    confirmation=payload.country_date_expansion,
                )
            except CountryVisitExpansionConflict as error:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail={
                        "code": "COUNTRY_VISIT_DATE_EXPANSION_STALE",
                        "message": str(error),
                    },
                ) from error

            return serialize_visit_with_city(visit, city, country)

        # No confirmation: check compatibility or return a proposal.
        check_country_visit_association(
            country_visit=country_visit,
            city_country_code=city.country_code,
            city_dates=city_dates,
            confirmation=None,
        )

    # Option 3: Create a standalone city visit.
    # Also handles an existing association with compatible dates.
    visit = repository.create(
        user_id=user.id,
        city_id=city.id,
        country_visit_id=payload.country_visit_id,
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
    """Update a city visit and validate its final country association."""

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

    # Omitted: preserve association.
    # Explicit null: remove association.
    # UUID: associate or change association.
    country_visit_id = changes.get(
        "country_visit_id",
        visit.country_visit_id,
    )

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

    city_dates = VisitDateRange(
        started_on=started_on,
        started_on_precision=started_on_precision,
        ended_on=ended_on,
        ended_on_precision=ended_on_precision,
    )

    # A confirmation must target an existing country visit.
    if payload.country_date_expansion is not None and country_visit_id is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Country date expansion requires an existing country visit.",
        )

    # Validate the final association before persisting changes.
    if country_visit_id is not None:
        country_visit = CountryVisitRepository(session).get_for_user(
            visit_id=country_visit_id,
            user_id=user.id,
        )

        if country_visit is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Country visit not found.",
            )

        # Expanding dates cannot resolve a geographic mismatch.
        if city.country_code != country_visit.country_code:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=("City and country visit must belong to the same country."),
            )

        # Apply a previously confirmed expansion atomically.
        if payload.country_date_expansion is not None:
            try:
                updated = apply_confirmed_country_date_expansion(
                    session=session,
                    user_id=user.id,
                    country_visit=country_visit,
                    city=city,
                    city_dates=city_dates,
                    confirmation=payload.country_date_expansion,
                    existing_city_visit=visit,
                )
            except CountryVisitExpansionConflict as error:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail={
                        "code": "COUNTRY_VISIT_DATE_EXPANSION_STALE",
                        "message": str(error),
                    },
                ) from error

            return serialize_visit_with_city(updated, city, country)

        # Without confirmation, validate normally or return HTTP 409.
        check_country_visit_association(
            country_visit=country_visit,
            city_country_code=city.country_code,
            city_dates=city_dates,
            confirmation=None,
        )

    # No expansion required: use the existing update workflow.
    updated = repository.update(
        visit=visit,
        city_id=city.id,
        country_visit_id=country_visit_id,
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
