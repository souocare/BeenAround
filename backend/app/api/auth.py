from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.api.dependencies import CurrentAuthentication, CurrentUser
from app.core.auth_constants import WEB_SESSION_COOKIE
from app.core.config import Settings, get_settings
from app.db.session import get_db
from app.models.auth_session import AuthSessionType
from app.repositories.auth_sessions import AuthSessionRepository
from app.schemas.auth import LoginRequest, LoginResponse
from app.schemas.setup import SetupResponse
from app.services.auth_sessions import AuthSessionService
from app.services.authentication import (
    AuthenticationService,
    InvalidCredentialsError,
)

router = APIRouter(prefix="/auth", tags=["Authentication"])

DatabaseSession = Annotated[Session, Depends(get_db)]
ApplicationSettings = Annotated[Settings, Depends(get_settings)]


@router.post("/login", response_model=LoginResponse)
def login(
    data: LoginRequest,
    response: Response,
    session: DatabaseSession,
    settings: ApplicationSettings,
) -> LoginResponse:
    authentication_service = AuthenticationService(session)

    try:
        user = authentication_service.authenticate(
            login=data.login,
            password=data.password,
        )
    except InvalidCredentialsError as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials.",
        ) from error

    session_service = AuthSessionService(
        session=session,
        repository=AuthSessionRepository(session),
        idle_expire_days=settings.session_idle_expire_days,
    )

    created_session = session_service.create(
        user_id=user.id,
        session_type=AuthSessionType.WEB,
    )

    response.set_cookie(
        key=WEB_SESSION_COOKIE,
        value=created_session.credential,
        max_age=settings.session_idle_expire_days * 24 * 60 * 60,
        httponly=True,
        secure=settings.environment != "development",
        samesite="lax",
        path="/api/v1",
    )

    response.headers["Cache-Control"] = "no-store"

    return LoginResponse(
        user=SetupResponse.model_validate(user),
    )


@router.get("/me", response_model=SetupResponse)
def get_me(user: CurrentUser) -> SetupResponse:
    """Return the currently authenticated user."""

    return SetupResponse.model_validate(user)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    response: Response,
    authentication: CurrentAuthentication,
    session: DatabaseSession,
    settings: ApplicationSettings,
) -> None:
    """Revoke the current Web session and clear its cookie."""

    session_service = AuthSessionService(
        session=session,
        repository=AuthSessionRepository(session),
        idle_expire_days=settings.session_idle_expire_days,
    )

    session_service.revoke_for_user(
        session_id=authentication.auth_session.id,
        user_id=authentication.user.id,
    )

    response.delete_cookie(
        key=WEB_SESSION_COOKIE,
        path="/api/v1",
        secure=settings.environment != "development",
        httponly=True,
        samesite="lax",
    )

    response.headers["Cache-Control"] = "no-store"
