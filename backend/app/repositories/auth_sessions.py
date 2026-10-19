from uuid import UUID
from datetime import datetime

from sqlalchemy import update
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.auth_session import AuthSession

from app.models.auth_session import AuthSessionType


class AuthSessionRepository:
    """Persistence operations for authentication sessions."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def add(self, auth_session: AuthSession) -> None:
        self._session.add(auth_session)

    def get_by_id(self, session_id: UUID) -> AuthSession | None:
        return self._session.get(AuthSession, session_id)

    def get_by_credential_hash(
        self,
        credential_hash: str,
    ) -> AuthSession | None:
        return self._session.scalar(
            select(AuthSession).where(AuthSession.credential_hash == credential_hash)
        )

    def list_by_user(self, user_id: UUID) -> list[AuthSession]:
        return list(
            self._session.scalars(select(AuthSession).where(AuthSession.user_id == user_id))
        )

    def rotate_mobile_credential(
        self,
        *,
        session_id: UUID,
        old_credential_hash: str,
        new_credential_hash: str,
        now: datetime,
    ) -> bool:
        """Atomically replace a valid Mobile refresh credential."""

        statement = (
            update(AuthSession)
            .where(
                AuthSession.id == session_id,
                AuthSession.session_type == AuthSessionType.MOBILE,
                AuthSession.credential_hash == old_credential_hash,
                AuthSession.revoked_at.is_(None),
                AuthSession.expires_at > now,
            )
            .values(
                credential_hash=new_credential_hash,
                last_used_at=now,
            )
            .execution_options(synchronize_session=False)
        )

        result = self._session.execute(statement)

        return result.rowcount == 1


    def revoke_mobile_by_credential_hash(
        self,
        *,
        credential_hash: str,
        now: datetime,
    ) -> bool:
        """Atomically revoke a Mobile session using its current credential."""

        statement = (
            update(AuthSession)
            .where(
                AuthSession.credential_hash == credential_hash,
                AuthSession.session_type == AuthSessionType.MOBILE,
                AuthSession.revoked_at.is_(None),
                AuthSession.expires_at > now,
            )
            .values(
                revoked_at=now,
            )
            .execution_options(synchronize_session=False)
        )

        result = self._session.execute(statement)

        return result.rowcount == 1