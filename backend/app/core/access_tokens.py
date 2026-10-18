from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import UUID

import jwt
from jwt.exceptions import InvalidTokenError

_ACCESS_TOKEN_ALGORITHM = "HS256"
_ACCESS_TOKEN_TYPE = "access"


class InvalidAccessTokenError(ValueError):
    """Raised when an access token cannot be safely validated."""


@dataclass(frozen=True, slots=True)
class AccessTokenClaims:
    """Validated claims extracted from a BeenAround access token."""

    user_id: UUID
    issued_at: datetime
    expires_at: datetime


class AccessTokenService:
    """Create and validate short-lived BeenAround access tokens."""

    def __init__(
        self,
        *,
        secret_key: str,
        expire_minutes: int,
    ) -> None:
        if len(secret_key.encode("utf-8")) < 32:
            raise ValueError("Access token secret key must contain at least 32 bytes.")

        if expire_minutes <= 0:
            raise ValueError("Access token expiration must be positive.")

        self._secret_key = secret_key
        self._expiration = timedelta(minutes=expire_minutes)

    @property
    def expiration(self) -> timedelta:
        """Return the configured access token lifetime."""
        return self._expiration

    def create(
        self,
        *,
        user_id: UUID,
        now: datetime | None = None,
    ) -> str:
        """Create a signed short-lived access token for a user."""
        issued_at = _normalize_datetime(now or datetime.now(UTC))
        expires_at = issued_at + self._expiration

        payload = {
            "sub": str(user_id),
            "type": _ACCESS_TOKEN_TYPE,
            "iat": issued_at,
            "exp": expires_at,
        }

        return jwt.encode(
            payload,
            self._secret_key,
            algorithm=_ACCESS_TOKEN_ALGORITHM,
        )

    def validate(self, token: str) -> AccessTokenClaims:
        """Validate an access token and return its trusted claims."""
        if not token.strip():
            raise InvalidAccessTokenError("Access token is empty.")

        try:
            payload = jwt.decode(
                token,
                self._secret_key,
                algorithms=[_ACCESS_TOKEN_ALGORITHM],
                options={
                    "require": [
                        "sub",
                        "type",
                        "iat",
                        "exp",
                    ],
                },
            )
        except InvalidTokenError as error:
            raise InvalidAccessTokenError("Access token is invalid or expired.") from error

        if payload.get("type") != _ACCESS_TOKEN_TYPE:
            raise InvalidAccessTokenError("Token is not an access token.")

        try:
            user_id = UUID(payload["sub"])
            issued_at = datetime.fromtimestamp(payload["iat"], tz=UTC)
            expires_at = datetime.fromtimestamp(payload["exp"], tz=UTC)
        except (KeyError, TypeError, ValueError, OverflowError) as error:
            raise InvalidAccessTokenError("Access token contains invalid claims.") from error

        return AccessTokenClaims(
            user_id=user_id,
            issued_at=issued_at,
            expires_at=expires_at,
        )


def _normalize_datetime(value: datetime) -> datetime:
    """Return an aware UTC datetime suitable for token timestamps."""
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)

    return value.astimezone(UTC)
