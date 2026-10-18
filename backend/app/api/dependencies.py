from dataclasses import dataclass
from typing import Annotated

from fastapi import Cookie, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.auth_constants import WEB_SESSION_COOKIE
from app.core.config import Settings, get_settings
from app.db.session import get_db
from app.models.auth_session import AuthSession
from app.models.user import User
from app.repositories.auth_sessions import AuthSessionRepository
from app.services.auth_sessions import AuthSessionService

DatabaseSession = Annotated[Session, Depends(get_db)]
ApplicationSettings = Annotated[Settings, Depends(get_settings)]


@dataclass(frozen=True, slots=True)
class AuthenticatedUser:
    user: User
    auth_session: AuthSession


def get_authenticated_user(
    session: DatabaseSession,
    settings: ApplicationSettings,
    credential: Annotated[
        str | None,
        Cookie(alias=WEB_SESSION_COOKIE),
    ] = None,
) -> AuthenticatedUser:
    """Resolve the current authenticated Web user."""

    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Authentication required.",
    )

    if not credential:
        raise unauthorized

    session_service = AuthSessionService(
        session=session,
        repository=AuthSessionRepository(session),
        idle_expire_days=settings.session_idle_expire_days,
    )

    auth_session = session_service.resolve(credential)

    if auth_session is None:
        raise unauthorized

    user = session.get(User, auth_session.user_id)

    if user is None or not user.is_active:
        raise unauthorized

    return AuthenticatedUser(
        user=user,
        auth_session=auth_session,
    )


CurrentAuthentication = Annotated[
    AuthenticatedUser,
    Depends(get_authenticated_user),
]


def get_current_user(
    authentication: CurrentAuthentication,
) -> User:
    """Return the current active user."""
    return authentication.user


CurrentUser = Annotated[User, Depends(get_current_user)]


def require_admin(
    user: CurrentUser,
) -> User:
    """Require an authenticated administrator."""

    if not user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Administrator access required.",
        )

    return user


AdminUser = Annotated[User, Depends(require_admin)]
