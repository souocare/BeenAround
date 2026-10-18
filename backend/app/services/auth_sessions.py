from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.session_credentials import (
    generate_session_credential,
    hash_session_credential,
)
from app.models.auth_session import AuthSession, AuthSessionType
from app.repositories.auth_sessions import AuthSessionRepository


@dataclass(frozen=True, slots=True)
class CreatedAuthSession:
    session: AuthSession
    credential: str


def normalize_datetime(value: datetime) -> datetime:
    """Normalize SQLite and timezone-aware datetimes to UTC."""
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)

    return value.astimezone(UTC)


class AuthSessionService:
    """Manage persistent authentication sessions."""

    def __init__(
        self,
        *,
        session: Session,
        repository: AuthSessionRepository,
        idle_expire_days: int,
    ) -> None:
        if idle_expire_days <= 0:
            raise ValueError("Session expiration must be positive.")

        self._session = session
        self._repository = repository
        self._idle_expiration = timedelta(days=idle_expire_days)

    def create(
        self,
        *,
        user_id: UUID,
        session_type: AuthSessionType,
        now: datetime | None = None,
    ) -> CreatedAuthSession:
        current_time = normalize_datetime(now or datetime.now(UTC))
        credential = generate_session_credential()

        auth_session = AuthSession(
            user_id=user_id,
            session_type=session_type,
            credential_hash=credential.hash,
            expires_at=current_time + self._idle_expiration,
            last_used_at=current_time,
        )

        self._repository.add(auth_session)
        self._session.commit()
        self._session.refresh(auth_session)

        return CreatedAuthSession(
            session=auth_session,
            credential=credential.value,
        )

    def resolve(
        self,
        credential: str,
        *,
        now: datetime | None = None,
    ) -> AuthSession | None:
        if not credential:
            return None

        auth_session = self._repository.get_by_credential_hash(hash_session_credential(credential))

        if auth_session is None:
            return None

        current_time = normalize_datetime(now or datetime.now(UTC))

        if auth_session.revoked_at is not None:
            return None

        if normalize_datetime(auth_session.expires_at) <= current_time:
            return None

        return auth_session

    def revoke(
        self,
        *,
        session_id: UUID,
        now: datetime | None = None,
    ) -> bool:
        auth_session = self._repository.get_by_id(session_id)

        if auth_session is None:
            return False

        if auth_session.revoked_at is None:
            auth_session.revoked_at = normalize_datetime(now or datetime.now(UTC))
            self._session.commit()

        return True

    def revoke_for_user(
        self,
        *,
        session_id: UUID,
        user_id: UUID,
        now: datetime | None = None,
    ) -> bool:
        auth_session = self._repository.get_by_id(session_id)

        if auth_session is None or auth_session.user_id != user_id:
            return False

        return self.revoke(session_id=session_id, now=now)
