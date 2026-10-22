from collections.abc import Generator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.access_tokens import AccessTokenService
from app.core.config import Settings, get_settings
from app.core.security import hash_password
from app.core.session_credentials import hash_session_credential
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
            secret_key="beenaround-test-secret-key-32-bytes-minimum",
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


def mobile_login_headers(client: TestClient) -> dict[str, str]:
    """Authenticate a Mobile client and return Bearer headers."""

    response = client.post(
        "/api/v1/auth/mobile/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    assert response.status_code == 200

    return {
        "Authorization": f"Bearer {response.json()['access_token']}",
    }


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


def test_mobile_session_cannot_authenticate_web_requests(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, session = auth_client

    user = session.query(User).filter_by(username="goncalo").one()

    session_service = AuthSessionService(
        session=session,
        repository=AuthSessionRepository(session),
        idle_expire_days=30,
    )

    mobile_session = session_service.create(
        user_id=user.id,
        session_type=AuthSessionType.MOBILE,
    )

    client.cookies.set(
        "beenaround_session",
        mobile_session.credential,
        path="/api/v1",
    )

    response = client.get("/api/v1/auth/me")

    assert response.status_code == 401
    assert response.json()["detail"] == "Authentication required."


def test_mobile_login_returns_access_and_refresh_tokens(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, session = auth_client

    response = client.post(
        "/api/v1/auth/mobile/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    assert response.status_code == 200

    body = response.json()

    assert body["token_type"] == "bearer"
    assert body["expires_in"] == 900
    assert body["user"]["username"] == "goncalo"
    assert body["access_token"]
    assert body["refresh_token"]
    assert body["access_token"] != body["refresh_token"]

    assert "password_hash" not in body
    assert response.headers["cache-control"] == "no-store"

    assert "beenaround_session" not in response.headers.get("set-cookie", "")

    token_service = AccessTokenService(
        secret_key="beenaround-test-secret-key-32-bytes-minimum",
        expire_minutes=15,
    )

    claims = token_service.validate(body["access_token"])

    auth_session = AuthSessionRepository(session).get_by_id(claims.session_id)

    assert auth_session is not None
    assert auth_session.user_id == claims.user_id
    assert auth_session.session_type == AuthSessionType.MOBILE
    assert auth_session.credential_hash == hash_session_credential(body["refresh_token"])


def test_mobile_login_rejects_invalid_password(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    response = client.post(
        "/api/v1/auth/mobile/login",
        json={
            "login": "goncalo",
            "password": "wrong-password",
        },
    )

    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid credentials."


def test_mobile_login_rejects_unknown_user(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    response = client.post(
        "/api/v1/auth/mobile/login",
        json={
            "login": "unknown",
            "password": TEST_PASSWORD,
        },
    )

    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid credentials."


def test_mobile_login_accepts_email_case_insensitively(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    response = client.post(
        "/api/v1/auth/mobile/login",
        json={
            "login": "  GONCALO@EXAMPLE.COM  ",
            "password": TEST_PASSWORD,
        },
    )

    assert response.status_code == 200


def test_mobile_login_does_not_create_web_cookie(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    response = client.post(
        "/api/v1/auth/mobile/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    assert response.status_code == 200
    assert "beenaround_session" not in client.cookies

    me_response = client.get("/api/v1/auth/me")

    assert me_response.status_code == 401


def test_mobile_me_requires_bearer_token(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    response = client.get("/api/v1/auth/mobile/me")

    assert response.status_code == 401
    assert response.headers["www-authenticate"] == "Bearer"


def test_mobile_me_returns_authenticated_user(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    response = client.get(
        "/api/v1/auth/mobile/me",
        headers=mobile_login_headers(client),
    )

    assert response.status_code == 200
    assert response.json()["username"] == "goncalo"
    assert "password_hash" not in response.json()


def test_mobile_me_rejects_invalid_token(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    response = client.get(
        "/api/v1/auth/mobile/me",
        headers={"Authorization": "Bearer invalid-token"},
    )

    assert response.status_code == 401


def test_mobile_me_rejects_revoked_session(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, session = auth_client

    headers = mobile_login_headers(client)
    token = headers["Authorization"].removeprefix("Bearer ")

    token_service = AccessTokenService(
        secret_key="beenaround-test-secret-key-32-bytes-minimum",
        expire_minutes=15,
    )

    claims = token_service.validate(token)

    service = AuthSessionService(
        session=session,
        repository=AuthSessionRepository(session),
        idle_expire_days=30,
    )

    assert service.revoke(session_id=claims.session_id)

    response = client.get(
        "/api/v1/auth/mobile/me",
        headers=headers,
    )

    assert response.status_code == 401


def test_mobile_me_rejects_web_session_token(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, session = auth_client

    web_login_response = client.post(
        "/api/v1/auth/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    assert web_login_response.status_code == 200

    user = session.query(User).filter_by(username="goncalo").one()

    web_session_credential = client.cookies.get("beenaround_session")

    assert web_session_credential is not None

    web_session = AuthSessionService(
        session=session,
        repository=AuthSessionRepository(session),
        idle_expire_days=30,
    ).resolve(web_session_credential)

    assert web_session is not None

    token = AccessTokenService(
        secret_key="beenaround-test-secret-key-32-bytes-minimum",
        expire_minutes=15,
    ).create(
        user_id=user.id,
        session_id=web_session.id,
    )

    response = client.get(
        "/api/v1/auth/mobile/me",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 401


def test_mobile_me_rejects_inactive_user(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, session = auth_client

    headers = mobile_login_headers(client)

    user = session.query(User).filter_by(username="goncalo").one()
    user.is_active = False
    session.commit()

    response = client.get(
        "/api/v1/auth/mobile/me",
        headers=headers,
    )

    assert response.status_code == 401


def test_web_me_does_not_accept_mobile_bearer_token(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    headers = mobile_login_headers(client)

    response = client.get(
        "/api/v1/auth/me",
        headers=headers,
    )

    assert response.status_code == 401


def test_mobile_refresh_rotates_tokens(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, session = auth_client

    login_response = client.post(
        "/api/v1/auth/mobile/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    assert login_response.status_code == 200

    original = login_response.json()

    response = client.post(
        "/api/v1/auth/mobile/refresh",
        json={
            "refresh_token": original["refresh_token"],
        },
    )

    assert response.status_code == 200

    refreshed = response.json()

    assert refreshed["access_token"]
    assert refreshed["refresh_token"] != original["refresh_token"]
    assert refreshed["token_type"] == "bearer"
    assert refreshed["expires_in"] == 900
    assert response.headers["cache-control"] == "no-store"

    token_service = AccessTokenService(
        secret_key="beenaround-test-secret-key-32-bytes-minimum",
        expire_minutes=15,
    )

    original_claims = token_service.validate(original["access_token"])
    refreshed_claims = token_service.validate(refreshed["access_token"])

    assert refreshed_claims.user_id == original_claims.user_id
    assert refreshed_claims.session_id == original_claims.session_id

    auth_session = AuthSessionRepository(session).get_by_id(
        refreshed_claims.session_id,
    )

    assert auth_session is not None
    assert auth_session.credential_hash == hash_session_credential(
        refreshed["refresh_token"],
    )


def test_mobile_refresh_rejects_reused_token(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    login_response = client.post(
        "/api/v1/auth/mobile/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    original_refresh_token = login_response.json()["refresh_token"]

    first_response = client.post(
        "/api/v1/auth/mobile/refresh",
        json={
            "refresh_token": original_refresh_token,
        },
    )

    assert first_response.status_code == 200

    second_response = client.post(
        "/api/v1/auth/mobile/refresh",
        json={
            "refresh_token": original_refresh_token,
        },
    )

    assert second_response.status_code == 401
    assert second_response.json()["detail"] == "Invalid refresh token."


def test_mobile_refresh_rejects_unknown_token(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    response = client.post(
        "/api/v1/auth/mobile/refresh",
        json={
            "refresh_token": "unknown-refresh-token",
        },
    )

    assert response.status_code == 401


def test_mobile_refresh_rejects_web_session_credential(
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

    web_credential = client.cookies.get("beenaround_session")

    assert web_credential is not None

    response = client.post(
        "/api/v1/auth/mobile/refresh",
        json={
            "refresh_token": web_credential,
        },
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 401


def test_mobile_refresh_rejects_missing_token(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    response = client.post(
        "/api/v1/auth/mobile/refresh",
        json={},
    )

    assert response.status_code == 422


def test_mobile_refresh_does_not_set_web_cookie(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    login_response = client.post(
        "/api/v1/auth/mobile/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    refresh_response = client.post(
        "/api/v1/auth/mobile/refresh",
        json={
            "refresh_token": login_response.json()["refresh_token"],
        },
    )

    assert refresh_response.status_code == 200
    assert "beenaround_session" not in refresh_response.headers.get(
        "set-cookie",
        "",
    )


def test_mobile_logout_revokes_session_and_access_token(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    login_response = client.post(
        "/api/v1/auth/mobile/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    assert login_response.status_code == 200

    tokens = login_response.json()

    headers = {
        "Authorization": f"Bearer {tokens['access_token']}",
    }

    before_logout = client.get(
        "/api/v1/auth/mobile/me",
        headers=headers,
    )

    assert before_logout.status_code == 200

    logout_response = client.post(
        "/api/v1/auth/mobile/logout",
        json={
            "refresh_token": tokens["refresh_token"],
        },
    )

    assert logout_response.status_code == 204
    assert logout_response.headers["cache-control"] == "no-store"

    after_logout = client.get(
        "/api/v1/auth/mobile/me",
        headers=headers,
    )

    assert after_logout.status_code == 401

    refresh_response = client.post(
        "/api/v1/auth/mobile/refresh",
        json={
            "refresh_token": tokens["refresh_token"],
        },
    )

    assert refresh_response.status_code == 401


def test_mobile_logout_is_idempotent(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    for _ in range(2):
        response = client.post(
            "/api/v1/auth/mobile/logout",
            json={
                "refresh_token": "unknown-refresh-token",
            },
        )

        assert response.status_code == 204


def test_old_refresh_token_cannot_logout_rotated_session(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    login_response = client.post(
        "/api/v1/auth/mobile/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    original = login_response.json()

    refresh_response = client.post(
        "/api/v1/auth/mobile/refresh",
        json={
            "refresh_token": original["refresh_token"],
        },
    )

    assert refresh_response.status_code == 200

    refreshed = refresh_response.json()

    logout_response = client.post(
        "/api/v1/auth/mobile/logout",
        json={
            "refresh_token": original["refresh_token"],
        },
    )

    assert logout_response.status_code == 204

    me_response = client.get(
        "/api/v1/auth/mobile/me",
        headers={
            "Authorization": f"Bearer {refreshed['access_token']}",
        },
    )

    assert me_response.status_code == 200

    second_refresh = client.post(
        "/api/v1/auth/mobile/refresh",
        json={
            "refresh_token": refreshed["refresh_token"],
        },
    )

    assert second_refresh.status_code == 200


def test_mobile_logout_does_not_revoke_web_session(
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

    web_credential = client.cookies.get("beenaround_session")

    assert web_credential is not None

    logout_response = client.post(
        "/api/v1/auth/mobile/logout",
        json={
            "refresh_token": web_credential,
        },
        headers={"Origin": "http://testserver"},
    )

    assert logout_response.status_code == 204

    me_response = client.get("/api/v1/auth/me")

    assert me_response.status_code == 200


def test_mobile_logout_unknown_token_returns_204(
    auth_client: tuple[TestClient, Session],
) -> None:
    client, _ = auth_client

    response = client.post(
        "/api/v1/auth/mobile/logout",
        json={
            "refresh_token": "invalid-token",
        },
    )

    assert response.status_code == 204
    assert response.content == b""
