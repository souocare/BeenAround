from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.auth_session import AuthSession


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
