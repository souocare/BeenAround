from collections.abc import Generator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.security import hash_password
from app.db.base import Base
from app.db.session import create_database_engine, get_db
from app.main import create_app
from app.models.auth_session import AuthSessionType
from app.models.user import User
from app.repositories.auth_sessions import AuthSessionRepository
from app.services.auth_sessions import AuthSessionService

TEST_PASSWORD = "correct-password-123"


@pytest.fixture
def auth_client(
    tmp_path: Path,
) -> Generator[tuple[TestClient, Session], None, None]:
    engine = create_database_engine(f"sqlite:///{tmp_path / 'auth_api.db'}")

    Base.metadata.create_all(engine)

    with Session(engine) as session:
        user = User(
            username="goncalo",
            email="goncalo@example.com",
            display_name="Gonçalo",
            password_hash=hash_password(TEST_PASSWORD),
        )
        session.add(user)
        session.commit()

        settings = Settings(
            _env_file=None,
            environment="development",
            csrf_allowed_origins=["http://testserver"],
        )

        app = create_app(settings=settings)

        def override_get_db() -> Generator[Session, None, None]:
            with Session(engine) as request_session:
                yield request_session

        app.dependency_overrides[get_db] = override_get_db
        app.dependency_overrides[get_settings] = lambda: settings

        with TestClient(app) as client:
            yield client, session

        app.dependency_overrides.clear()

    engine.dispose()


def test_login_returns_user_and_sets_httponly_cookie(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    response = client.post(
        "/api/v1/auth/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    assert response.status_code == 200

    body = response.json()

    assert body["user"]["username"] == "goncalo"
    assert body["user"]["display_name"] == "Gonçalo"
    assert "password_hash" not in str(body)
    assert "credential" not in str(body)

    cookie = response.headers["set-cookie"]

    assert "beenaround_session=" in cookie
    assert "httponly" in cookie.lower()
    assert "samesite=lax" in cookie.lower()
    assert "path=/api/v1" in cookie.lower()
    assert response.headers["cache-control"] == "no-store"


def test_login_creates_persistent_web_session(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, session = auth_client

    response = client.post(
        "/api/v1/auth/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    assert response.status_code == 200

    credential = client.cookies.get("beenaround_session")

    assert credential is not None

    service = AuthSessionService(
        session=session,
        repository=AuthSessionRepository(session),
        idle_expire_days=30,
    )

    auth_session = service.resolve(credential)

    assert auth_session is not None
    assert auth_session.session_type == AuthSessionType.WEB
    assert auth_session.credential_hash != credential


def test_login_rejects_invalid_password(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    response = client.post(
        "/api/v1/auth/login",
        json={
            "login": "goncalo",
            "password": "wrong-password",
        },
    )

    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid credentials."
    assert "beenaround_session" not in response.headers.get("set-cookie", "")


def test_login_rejects_unknown_user(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    response = client.post(
        "/api/v1/auth/login",
        json={
            "login": "unknown",
            "password": TEST_PASSWORD,
        },
    )

    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid credentials."


def test_login_accepts_email_case_insensitively(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    response = client.post(
        "/api/v1/auth/login",
        json={
            "login": "  GONCALO@EXAMPLE.COM  ",
            "password": TEST_PASSWORD,
        },
    )

    assert response.status_code == 200


def test_login_does_not_return_session_credential_in_json(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    response = client.post(
        "/api/v1/auth/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    assert response.status_code == 200

    credential = client.cookies.get("beenaround_session")

    assert credential is not None
    assert credential not in response.text


def test_me_requires_authentication(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    response = client.get("/api/v1/auth/me")

    assert response.status_code == 401


def test_me_returns_authenticated_user(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    assert login_response.status_code == 200

    response = client.get("/api/v1/auth/me")

    assert response.status_code == 200
    assert response.json()["username"] == "goncalo"
    assert "password_hash" not in response.json()


def test_logout_revokes_session(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, session = auth_client

    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    assert login_response.status_code == 200

    credential = client.cookies.get("beenaround_session")

    assert credential is not None

    logout_response = client.post(
        "/api/v1/auth/logout",
        headers={"Origin": "http://testserver"},
    )

    assert logout_response.status_code == 204
    assert "beenaround_session" not in client.cookies

    session_service = AuthSessionService(
        session=session,
        repository=AuthSessionRepository(session),
        idle_expire_days=30,
    )

    assert session_service.resolve(credential) is None


def test_revoked_session_cannot_access_me(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    client.post(
        "/api/v1/auth/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    credential = client.cookies.get("beenaround_session")

    assert credential is not None

    client.post(
        "/api/v1/auth/logout",
        headers={"Origin": "http://testserver"},
    )

    response = client.get(
        "/api/v1/auth/me",
        cookies={"beenaround_session": credential},
    )

    assert response.status_code == 401


def test_logout_requires_authentication(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    response = client.post(
        "/api/v1/auth/logout",
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 401


def test_inactive_user_cannot_access_me(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, session = auth_client

    client.post(
        "/api/v1/auth/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    user = session.query(User).filter_by(username="goncalo").one()
    user.is_active = False
    session.commit()

    response = client.get("/api/v1/auth/me")

    assert response.status_code == 401


def test_logout_rejects_external_origin(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    client.post(
        "/api/v1/auth/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    response = client.post(
        "/api/v1/auth/logout",
        headers={"Origin": "https://evil.example"},
    )

    assert response.status_code == 403

    # The rejected request must not revoke the session.
    assert client.get("/api/v1/auth/me").status_code == 200


def test_logout_rejects_missing_origin_and_referer(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    client.post(
        "/api/v1/auth/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    response = client.post("/api/v1/auth/logout")

    assert response.status_code == 403


def test_logout_accepts_valid_referer(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    client.post(
        "/api/v1/auth/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    response = client.post(
        "/api/v1/auth/logout",
        headers={"Referer": "http://testserver/trips"},
    )

    assert response.status_code == 204


def test_csrf_protection_applies_to_other_endpoints(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    assert login_response.status_code == 200

    response = client.post(
        "/api/v1/setup",
        json={
            "username": "anotheruser",
            "display_name": "Another User",
            "password": "another-password-123",
        },
        headers={"Origin": "https://evil.example"},
    )

    assert response.status_code == 403
    assert response.json()["detail"] == "Invalid request origin."


def test_csrf_does_not_block_unauthenticated_requests(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    client.cookies.clear()

    response = client.post(
        "/api/v1/auth/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
        headers={"Origin": "https://evil.example"},
    )

    assert response.status_code == 200
