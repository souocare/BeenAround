from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.api.dependencies import (
    CurrentAuthentication,
    CurrentMobileUser,
    CurrentUser,
)
from app.core.auth_constants import WEB_SESSION_COOKIE
from app.core.config import Settings, get_settings
from app.db.session import get_db
from app.models.auth_session import AuthSessionType
from app.repositories.auth_sessions import AuthSessionRepository
from app.schemas.auth import LoginRequest, LoginResponse, MobileLogoutRequest
from app.schemas.setup import SetupResponse
from app.services.auth_sessions import AuthSessionService
from app.services.authentication import (
    AuthenticationService,
    InvalidCredentialsError,
)
from app.core.access_tokens import AccessTokenService
from app.schemas.auth import LoginRequest, LoginResponse, MobileLoginResponse
from app.schemas.auth import MobileRefreshRequest, MobileRefreshResponse
from app.services.auth_sessions import InvalidRefreshTokenError


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

@router.post(
    "/mobile/login",
    response_model=MobileLoginResponse,
)
def mobile_login(
    data: LoginRequest,
    response: Response,
    session: DatabaseSession,
    settings: ApplicationSettings,
) -> MobileLoginResponse:
    """Authenticate a mobile client and issue session-bound tokens."""

    if not settings.secret_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Mobile authentication is not configured.",
        )

    token_service = AccessTokenService(
        secret_key=settings.secret_key,
        expire_minutes=settings.access_token_expire_minutes,
    )

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
        session_type=AuthSessionType.MOBILE,
    )

    access_token = token_service.create(
        user_id=user.id,
        session_id=created_session.session.id,
    )

    response.headers["Cache-Control"] = "no-store"

    return MobileLoginResponse(
        access_token=access_token,
        refresh_token=created_session.credential,
        expires_in=int(token_service.expiration.total_seconds()),
        user=SetupResponse.model_validate(user),
    )

@router.get(
    "/mobile/me",
    response_model=SetupResponse,
)
def get_mobile_me(
    user: CurrentMobileUser,
) -> SetupResponse:
    """Return the currently authenticated Mobile user."""

    return SetupResponse.model_validate(user)


@router.post(
    "/mobile/refresh",
    response_model=MobileRefreshResponse,
)
def mobile_refresh(
    data: MobileRefreshRequest,
    response: Response,
    session: DatabaseSession,
    settings: ApplicationSettings,
) -> MobileRefreshResponse:
    """Rotate a Mobile refresh credential and issue a new access token."""

    if not settings.secret_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Mobile authentication is not configured.",
        )

    token_service = AccessTokenService(
        secret_key=settings.secret_key,
        expire_minutes=settings.access_token_expire_minutes,
    )

    session_service = AuthSessionService(
        session=session,
        repository=AuthSessionRepository(session),
        idle_expire_days=settings.session_idle_expire_days,
    )

    try:
        rotated = session_service.rotate_mobile_credential(
            data.refresh_token,
        )
    except InvalidRefreshTokenError as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from error

    access_token = token_service.create(
        user_id=rotated.session.user_id,
        session_id=rotated.session.id,
    )

    response.headers["Cache-Control"] = "no-store"

    return MobileRefreshResponse(
        access_token=access_token,
        refresh_token=rotated.credential,
        expires_in=int(token_service.expiration.total_seconds()),
    )


@router.post(
    "/mobile/logout",
    status_code=status.HTTP_204_NO_CONTENT,
)
def mobile_logout(
    data: MobileLogoutRequest,
    response: Response,
    session: DatabaseSession,
    settings: ApplicationSettings,
) -> None:
    """Revoke the Mobile session associated with the current refresh token."""

    session_service = AuthSessionService(
        session=session,
        repository=AuthSessionRepository(session),
        idle_expire_days=settings.session_idle_expire_days,
    )

    session_service.revoke_mobile_credential(
        data.refresh_token,
    )

    response.headers["Cache-Control"] = "no-store"