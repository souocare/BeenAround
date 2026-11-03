"""Historical residence REST endpoints."""

from uuid import UUID

from fastapi import APIRouter, HTTPException, status
from sqlalchemy.engine import Engine

from app.api.dependencies import CurrentApiUser, DatabaseSession
from app.repositories.residences import ResidenceRepository
from app.schemas.residences import (
    ResidenceCreate,
    ResidenceListResponse,
    ResidenceResponse,
    ResidenceUpdate,
)
from app.services.residence_writes import (
    ResidenceNotFound,
    create_residence as create_residence_record,
    delete_residence as delete_residence_record,
    update_residence as update_residence_record,
)
from app.services.residences import (
    ResidenceDestinationNotFound,
    ResidenceOverlapRequired,
    ResidenceOverlapStale,
)


router = APIRouter(
    prefix="/residences",
    tags=["Residences"],
)


def get_write_engine(session: DatabaseSession) -> Engine:
    """Resolve the configured engine for dedicated residence writes."""

    bind = session.get_bind()

    if not isinstance(bind, Engine):
        raise RuntimeError("Residence write operations require an engine-bound session.")

    return bind


def residence_write_error(error: Exception) -> HTTPException:
    """Translate residence application errors into HTTP responses."""

    if isinstance(error, ResidenceNotFound):
        return HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Residence not found.",
        )

    if isinstance(error, ResidenceDestinationNotFound):
        return HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(error),
        )

    if isinstance(error, ResidenceOverlapRequired):
        return HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "RESIDENCE_PERIOD_OVERLAP",
                "message": str(error),
                "requested": error.requested.model_dump(mode="json"),
                "overlaps": [overlap.model_dump(mode="json") for overlap in error.overlaps],
                "expected_target": (
                    error.expected_target.model_dump(mode="json")
                    if error.expected_target is not None
                    else None
                ),
            },
        )

    if isinstance(error, ResidenceOverlapStale):
        return HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "RESIDENCE_OVERLAP_CONFIRMATION_STALE",
                "message": str(error),
            },
        )

    if isinstance(error, ValueError):
        return HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(error),
        )

    raise TypeError("Unsupported residence application error.")


@router.get(
    "",
    response_model=ResidenceListResponse,
)
def list_residences(
    user: CurrentApiUser,
    session: DatabaseSession,
) -> ResidenceListResponse:
    """List the authenticated user's historical residences."""

    repository = ResidenceRepository(session)

    residences = repository.list_for_user(user.id)

    return ResidenceListResponse(
        items=[ResidenceResponse.model_validate(residence) for residence in residences],
        total=len(residences),
    )


@router.get(
    "/{residence_id}",
    response_model=ResidenceResponse,
)
def get_residence(
    residence_id: UUID,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> ResidenceResponse:
    """Retrieve an owned historical residence."""

    repository = ResidenceRepository(session)

    residence = repository.get_for_user(
        residence_id=residence_id,
        user_id=user.id,
    )

    if residence is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Residence not found.",
        )

    return ResidenceResponse.model_validate(residence)


@router.post(
    "",
    response_model=ResidenceResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_residence(
    payload: ResidenceCreate,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> ResidenceResponse:
    """Create a residence after validating overlaps and confirmation."""

    try:
        residence = create_residence_record(
            engine=get_write_engine(session),
            user_id=user.id,
            payload=payload,
        )

    except (
        ResidenceDestinationNotFound,
        ResidenceOverlapRequired,
        ResidenceOverlapStale,
        ValueError,
    ) as error:
        raise residence_write_error(error) from error

    return ResidenceResponse.model_validate(residence)


@router.patch(
    "/{residence_id}",
    response_model=ResidenceResponse,
)
def update_residence(
    residence_id: UUID,
    payload: ResidenceUpdate,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> ResidenceResponse:
    """Update an owned residence with overlap protection."""

    try:
        residence = update_residence_record(
            engine=get_write_engine(session),
            user_id=user.id,
            residence_id=residence_id,
            payload=payload,
        )

    except (
        ResidenceNotFound,
        ResidenceDestinationNotFound,
        ResidenceOverlapRequired,
        ResidenceOverlapStale,
        ValueError,
    ) as error:
        raise residence_write_error(error) from error

    return ResidenceResponse.model_validate(residence)


@router.delete(
    "/{residence_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_residence(
    residence_id: UUID,
    user: CurrentApiUser,
    session: DatabaseSession,
) -> None:
    """Delete an owned historical residence."""

    try:
        delete_residence_record(
            engine=get_write_engine(session),
            user_id=user.id,
            residence_id=residence_id,
        )

    except ResidenceNotFound as error:
        raise residence_write_error(error) from error
