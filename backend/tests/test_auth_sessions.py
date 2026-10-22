from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime, timedelta
from pathlib import Path
from threading import Barrier

import pytest
from sqlalchemy import select
from sqlalchemy.exc import OperationalError
from sqlalchemy.orm import Session

from app.core.session_credentials import (
    generate_session_credential,
    hash_session_credential,
)
from app.db.base import Base
from app.db.session import create_database_engine
from app.models.auth_session import AuthSession, AuthSessionType
from app.models.user import User
from app.repositories.auth_sessions import AuthSessionRepository
from app.services.auth_sessions import (
    AuthSessionService,
    InvalidRefreshTokenError,
)


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


def test_rotate_mobile_credential_is_single_use(session_environment) -> None:
    session, user_id = session_environment

    service = make_service(session)

    created = service.create(
        user_id=user_id,
        session_type=AuthSessionType.MOBILE,
    )

    repository = AuthSessionRepository(session)

    new_credential = generate_session_credential()
    now = datetime.now(UTC)

    first_rotation = repository.rotate_mobile_credential(
        session_id=created.session.id,
        old_credential_hash=hash_session_credential(created.credential),
        new_credential_hash=new_credential.hash,
        now=now,
    )

    assert first_rotation is True

    session.commit()
    session.expire_all()

    second_rotation = repository.rotate_mobile_credential(
        session_id=created.session.id,
        old_credential_hash=hash_session_credential(created.credential),
        new_credential_hash=generate_session_credential().hash,
        now=now,
    )

    assert second_rotation is False

    session.rollback()

    assert service.resolve(created.credential) is None
    assert service.resolve(new_credential.value) is not None


def test_rotate_mobile_credential_rejects_web_session(session_environment) -> None:
    session, user_id = session_environment

    created = make_service(session).create(
        user_id=user_id,
        session_type=AuthSessionType.WEB,
    )

    rotated = AuthSessionRepository(session).rotate_mobile_credential(
        session_id=created.session.id,
        old_credential_hash=hash_session_credential(created.credential),
        new_credential_hash=generate_session_credential().hash,
        now=datetime.now(UTC),
    )

    assert rotated is False

    session.rollback()


def test_repository_rotate_mobile_credential_rejects_revoked_session(
    session_environment,
) -> None:
    session, user_id = session_environment

    service = make_service(session)

    created = service.create(
        user_id=user_id,
        session_type=AuthSessionType.MOBILE,
    )

    assert service.revoke(session_id=created.session.id)

    rotated = AuthSessionRepository(session).rotate_mobile_credential(
        session_id=created.session.id,
        old_credential_hash=hash_session_credential(created.credential),
        new_credential_hash=generate_session_credential().hash,
        now=datetime.now(UTC),
    )

    assert rotated is False

    session.rollback()


def test_repository_rotate_mobile_credential_rejects_expired_session(
    session_environment,
) -> None:
    session, user_id = session_environment

    service = make_service(session)

    created = service.create(
        user_id=user_id,
        session_type=AuthSessionType.MOBILE,
        now=datetime(2026, 1, 1, tzinfo=UTC),
    )

    rotated = AuthSessionRepository(session).rotate_mobile_credential(
        session_id=created.session.id,
        old_credential_hash=hash_session_credential(created.credential),
        new_credential_hash=generate_session_credential().hash,
        now=datetime.now(UTC),
    )

    assert rotated is False

    session.rollback()


def test_rotate_mobile_session_credential(session_environment) -> None:
    session, user_id = session_environment
    service = make_service(session)

    created = service.create(
        user_id=user_id,
        session_type=AuthSessionType.MOBILE,
    )

    rotated = service.rotate_mobile_credential(created.credential)

    assert rotated.session.id == created.session.id
    assert rotated.credential != created.credential

    assert service.resolve(created.credential) is None
    assert service.resolve(rotated.credential) is not None


def test_rotated_mobile_credential_cannot_be_reused(session_environment) -> None:
    session, user_id = session_environment
    service = make_service(session)

    created = service.create(
        user_id=user_id,
        session_type=AuthSessionType.MOBILE,
    )

    service.rotate_mobile_credential(created.credential)

    with pytest.raises(InvalidRefreshTokenError):
        service.rotate_mobile_credential(created.credential)


def test_rotate_mobile_credential_rejects_web_credential(session_environment) -> None:
    session, user_id = session_environment
    service = make_service(session)

    created = service.create(
        user_id=user_id,
        session_type=AuthSessionType.WEB,
    )

    with pytest.raises(InvalidRefreshTokenError):
        service.rotate_mobile_credential(created.credential)


def test_rotate_mobile_credential_rejects_revoked_session(session_environment) -> None:
    session, user_id = session_environment
    service = make_service(session)

    created = service.create(
        user_id=user_id,
        session_type=AuthSessionType.MOBILE,
    )

    service.revoke(session_id=created.session.id)

    with pytest.raises(InvalidRefreshTokenError):
        service.rotate_mobile_credential(created.credential)


def test_rotate_mobile_credential_rejects_expired_session(session_environment) -> None:
    session, user_id = session_environment
    service = make_service(session)

    created = service.create(
        user_id=user_id,
        session_type=AuthSessionType.MOBILE,
        now=datetime(2026, 1, 1, tzinfo=UTC),
    )

    with pytest.raises(InvalidRefreshTokenError):
        service.rotate_mobile_credential(
            created.credential,
            now=datetime(2026, 2, 1, tzinfo=UTC),
        )


def test_rotate_mobile_credential_rejects_inactive_user(session_environment) -> None:
    session, user_id = session_environment
    service = make_service(session)

    created = service.create(
        user_id=user_id,
        session_type=AuthSessionType.MOBILE,
    )

    user = session.get(User, user_id)
    assert user is not None

    user.is_active = False
    session.commit()

    with pytest.raises(InvalidRefreshTokenError):
        service.rotate_mobile_credential(created.credential)


def test_rotate_mobile_credential_preserves_expiration(session_environment) -> None:
    session, user_id = session_environment
    service = make_service(session)

    created = service.create(
        user_id=user_id,
        session_type=AuthSessionType.MOBILE,
    )

    original_expiration = created.session.expires_at

    rotated = service.rotate_mobile_credential(created.credential)

    assert rotated.session.expires_at == original_expiration


def test_rotate_mobile_credential_rejects_empty_token(session_environment) -> None:
    session, _ = session_environment
    service = make_service(session)

    with pytest.raises(InvalidRefreshTokenError):
        service.rotate_mobile_credential("")


def test_concurrent_mobile_refresh_allows_only_one_rotation(
    tmp_path: Path,
) -> None:
    engine = create_database_engine(f"sqlite:///{tmp_path / 'concurrent_sessions.db'}")
    Base.metadata.create_all(engine)

    try:
        with Session(engine) as session:
            user = User(
                username="concurrent-user",
                display_name="Concurrent User",
                password_hash="test-hash",
            )
            session.add(user)
            session.commit()

            created = make_service(session).create(
                user_id=user.id,
                session_type=AuthSessionType.MOBILE,
            )

            original_credential = created.credential

        barrier = Barrier(2)

        def attempt_rotation() -> bool:
            with Session(engine) as session:
                service = make_service(session)

                barrier.wait(timeout=10)

                try:
                    service.rotate_mobile_credential(original_credential)
                except InvalidRefreshTokenError:
                    return False
                except OperationalError:
                    # SQLite can reject competing writes under contention.
                    session.rollback()
                    return False

                return True

        with ThreadPoolExecutor(max_workers=2) as executor:
            futures = [executor.submit(attempt_rotation) for _ in range(2)]

            results = [future.result(timeout=15) for future in futures]

        assert sorted(results) == [False, True]

        with Session(engine) as session:
            repository = AuthSessionRepository(session)

            saved = repository.get_by_id(created.session.id)

            assert saved is not None
            assert saved.credential_hash != hash_session_credential(original_credential)

    finally:
        engine.dispose()
