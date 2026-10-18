from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.session_credentials import hash_session_credential
from app.db.base import Base
from app.db.session import create_database_engine
from app.models.auth_session import AuthSession, AuthSessionType
from app.models.user import User
from app.repositories.auth_sessions import AuthSessionRepository
from app.services.auth_sessions import AuthSessionService


@pytest.fixture
def session_environment(tmp_path: Path):
    engine = create_database_engine(f"sqlite:///{tmp_path / 'sessions.db'}")
    Base.metadata.create_all(engine)

    with Session(engine) as session:
        user = User(
            username="testuser",
            display_name="Test User",
            password_hash="test-hash",
        )
        session.add(user)
        session.commit()

        user_id = user.id

        yield session, user_id

    engine.dispose()


def make_service(session: Session) -> AuthSessionService:
    return AuthSessionService(
        session=session,
        repository=AuthSessionRepository(session),
        idle_expire_days=30,
    )


def test_create_session(session_environment) -> None:
    session, user_id = session_environment
    service = make_service(session)

    created = service.create(
        user_id=user_id,
        session_type=AuthSessionType.WEB,
    )

    assert created.session.user_id == user_id
    assert created.session.session_type == AuthSessionType.WEB
    assert created.session.credential_hash == hash_session_credential(created.credential)
    assert created.credential != created.session.credential_hash


def test_resolve_valid_session(session_environment) -> None:
    session, user_id = session_environment
    service = make_service(session)

    created = service.create(
        user_id=user_id,
        session_type=AuthSessionType.MOBILE,
    )

    resolved = service.resolve(created.credential)

    assert resolved is not None
    assert resolved.id == created.session.id


def test_expired_session_is_rejected(session_environment) -> None:
    session, user_id = session_environment
    service = make_service(session)

    created_at = datetime(2026, 1, 1, tzinfo=UTC)

    created = service.create(
        user_id=user_id,
        session_type=AuthSessionType.WEB,
        now=created_at,
    )

    resolved = service.resolve(
        created.credential,
        now=created_at + timedelta(days=31),
    )

    assert resolved is None


def test_revoked_session_is_rejected(session_environment) -> None:
    session, user_id = session_environment
    service = make_service(session)

    created = service.create(
        user_id=user_id,
        session_type=AuthSessionType.WEB,
    )

    assert service.revoke(session_id=created.session.id)

    assert service.resolve(created.credential) is None


def test_user_cannot_revoke_another_users_session(session_environment) -> None:
    session, user_id = session_environment
    service = make_service(session)

    created = service.create(
        user_id=user_id,
        session_type=AuthSessionType.WEB,
    )

    from uuid import uuid4

    assert not service.revoke_for_user(
        session_id=created.session.id,
        user_id=uuid4(),
    )

    assert service.resolve(created.credential) is not None


def test_session_is_persisted(session_environment) -> None:
    session, user_id = session_environment
    service = make_service(session)

    created = service.create(
        user_id=user_id,
        session_type=AuthSessionType.WEB,
    )

    saved = session.scalar(select(AuthSession).where(AuthSession.id == created.session.id))

    assert saved is not None
    assert saved.credential_hash == hash_session_credential(created.credential)
