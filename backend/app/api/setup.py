from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.setup import SetupRequest, SetupResponse, SetupStatusResponse
from app.services.setup import (
    SetupAlreadyCompletedError,
    create_initial_admin,
    is_setup_required,
)

router = APIRouter(prefix="/setup", tags=["Setup"])
DatabaseSession = Annotated[Session, Depends(get_db)]


@router.get("/status", response_model=SetupStatusResponse)
def get_setup_status(
    session: DatabaseSession,
) -> SetupStatusResponse:
    return SetupStatusResponse(
        setup_required=is_setup_required(session),
    )


@router.post(
    "",
    response_model=SetupResponse,
    status_code=status.HTTP_201_CREATED,
)
def complete_setup(
    data: SetupRequest,
    session: DatabaseSession,
) -> SetupResponse:
    try:
        user = create_initial_admin(session, data)
    except SetupAlreadyCompletedError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Initial setup has already been completed.",
        ) from exc

    return SetupResponse.model_validate(user)
