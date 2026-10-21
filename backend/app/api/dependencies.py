"""Authentication and database dependencies."""

from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Annotated

from fastapi import Cookie, Depends, Header, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.access_tokens import AccessTokenService, InvalidAccessTokenError
from app.core.auth_constants import WEB_SESSION_COOKIE
from app.core.config import Settings, get_settings
from app.db.session import get_db
from app.models.auth_session import AuthSession, AuthSessionType
from app.models.user import User
from app.repositories.auth_sessions import AuthSessionRepository
from app.services.auth_sessions import AuthSessionService, normalize_datetime


DatabaseSession = Annotated[Session, Depends(get_db)]
ApplicationSettings = Annotated[Settings, Depends(get_settings)]


@dataclass(frozen=True, slots=True)
class AuthenticatedUser:
    user: User
    auth_session: AuthSession


def _unauthorized(*, bearer: bool = False) -> HTTPException:
    """Create a consistent authentication failure."""

    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Authentication required.",
        headers={"WWW-Authenticate": "Bearer"} if bearer else None,
    )


def _resolve_web_authentication(
    *,
    session: Session,
    settings: Settings,
    credential: str | None,
) -> AuthenticatedUser:
    """Validate a Web session cookie."""

    if not credential:
        raise _unauthorized()

    session_service = AuthSessionService(
        session=session,
        repository=AuthSessionRepository(session),
        idle_expire_days=settings.session_idle_expire_days,
    )

    auth_session = session_service.resolve(credential)

    if auth_session is None or auth_session.session_type != AuthSessionType.WEB:
        raise _unauthorized()

    user = session.get(User, auth_session.user_id)

    if user is None or not user.is_active:
        raise _unauthorized()

    return AuthenticatedUser(
        user=user,
        auth_session=auth_session,
    )


def _resolve_mobile_authentication(
    *,
    session: Session,
    settings: Settings,
    token: str,
) -> AuthenticatedUser:
    """Validate a Mobile access token and its associated session."""

    if not settings.secret_key:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Mobile authentication is not configured.",
        )

    token_service = AccessTokenService(
        secret_key=settings.secret_key,
        expire_minutes=settings.access_token_expire_minutes,
    )

    try:
        claims = token_service.validate(token)
    except InvalidAccessTokenError as error:
        raise _unauthorized(bearer=True) from error

    auth_session = AuthSessionRepository(session).get_by_id(claims.session_id)

    if (
        auth_session is None
        or auth_session.session_type != AuthSessionType.MOBILE
        or auth_session.user_id != claims.user_id
        or auth_session.revoked_at is not None
        or normalize_datetime(auth_session.expires_at) <= datetime.now(UTC)
    ):
        raise _unauthorized(bearer=True)

    user = session.get(User, claims.user_id)

    if user is None or not user.is_active:
        raise _unauthorized(bearer=True)

    return AuthenticatedUser(
        user=user,
        auth_session=auth_session,
    )


def get_authenticated_user(
    session: DatabaseSession,
    settings: ApplicationSettings,
    credential: Annotated[
        str | None,
        Cookie(alias=WEB_SESSION_COOKIE),
    ] = None,
) -> AuthenticatedUser:
    """Resolve the current authenticated Web user."""

    return _resolve_web_authentication(
        session=session,
        settings=settings,
        credential=credential,
    )


mobile_bearer_scheme = HTTPBearer(auto_error=False)


def get_authenticated_mobile_user(
    session: DatabaseSession,
    settings: ApplicationSettings,
    credentials: Annotated[
        HTTPAuthorizationCredentials | None,
        Depends(mobile_bearer_scheme),
    ],
) -> AuthenticatedUser:
    """Resolve the current authenticated Mobile user."""

    if credentials is None or credentials.scheme.lower() != "bearer":
        raise _unauthorized(bearer=True)

    return _resolve_mobile_authentication(
        session=session,
        settings=settings,
        token=credentials.credentials,
    )


CurrentAuthentication = Annotated[
    AuthenticatedUser,
    Depends(get_authenticated_user),
]


def get_current_user(
    authentication: CurrentAuthentication,
) -> User:
    """Return the current active Web user."""

    return authentication.user


CurrentUser = Annotated[User, Depends(get_current_user)]


def require_admin(user: CurrentUser) -> User:
    """Require an authenticated administrator."""

    if not user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Administrator access required.",
        )

    return user


AdminUser = Annotated[User, Depends(require_admin)]


CurrentMobileAuthentication = Annotated[
    AuthenticatedUser,
    Depends(get_authenticated_mobile_user),
]


def get_current_mobile_user(
    authentication: CurrentMobileAuthentication,
) -> User:
    """Return the current active Mobile user."""

    return authentication.user


CurrentMobileUser = Annotated[
    User,
    Depends(get_current_mobile_user),
]


def get_current_api_user(
    session: DatabaseSession,
    settings: ApplicationSettings,
    authorization: Annotated[str | None, Header()] = None,
    credential: Annotated[
        str | None,
        Cookie(alias=WEB_SESSION_COOKIE),
    ] = None,
) -> User:
    """Authenticate domain API requests using Web or Mobile credentials."""

    if authorization is not None:
        scheme, separator, token = authorization.partition(" ")

        if not separator or scheme.lower() != "bearer" or not token.strip():
            raise _unauthorized(bearer=True)

        authentication = _resolve_mobile_authentication(
            session=session,
            settings=settings,
            token=token.strip(),
        )

        return authentication.user

    authentication = _resolve_web_authentication(
        session=session,
        settings=settings,
        credential=credential,
    )

    return authentication.user


CurrentApiUser = Annotated[
    User,
    Depends(get_current_api_user),
]
