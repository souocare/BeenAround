"""Tests for the authenticated country catalog API."""

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
from app.models.country import Country
from app.models.user import User

TEST_PASSWORD = "correct-password-123"


@pytest.fixture
def countries_client(
    tmp_path: Path,
) -> Generator[TestClient, None, None]:
    engine = create_database_engine(f"sqlite:///{tmp_path / 'countries_api.db'}")

    Base.metadata.create_all(engine)

    with Session(engine) as session:
        session.add_all(
            [
                Country(
                    code="PT",
                    name="Portugal",
                    alpha3_code="PRT",
                ),
                Country(
                    code="ES",
                    name="Spain",
                    alpha3_code="ESP",
                ),
                Country(
                    code="LK",
                    name="Sri Lanka",
                    alpha3_code="LKA",
                ),
            ]
        )

        session.add(
            User(
                username="goncalo",
                email="goncalo@example.com",
                display_name="Gonçalo",
                password_hash=hash_password(TEST_PASSWORD),
            )
        )

        session.commit()

    settings = Settings(
        _env_file=None,
        environment="development",
        csrf_allowed_origins=["http://testserver"],
        secret_key="beenaround-test-secret-key-32-bytes-minimum",
    )

    app = create_app(settings=settings)

    def override_get_db() -> Generator[Session, None, None]:
        with Session(engine) as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_settings] = lambda: settings

    with TestClient(app) as client:
        yield client

    app.dependency_overrides.clear()
    engine.dispose()


def web_login(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    assert response.status_code == 200


def mobile_headers(client: TestClient) -> dict[str, str]:
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


def test_countries_requires_authentication(
    countries_client: TestClient,
) -> None:
    response = countries_client.get("/api/v1/countries")

    assert response.status_code == 401


def test_country_details_requires_authentication(
    countries_client: TestClient,
) -> None:
    response = countries_client.get("/api/v1/countries/PT")

    assert response.status_code == 401


def test_web_user_can_list_countries(
    countries_client: TestClient,
) -> None:
    web_login(countries_client)

    response = countries_client.get("/api/v1/countries")

    assert response.status_code == 200

    body = response.json()

    assert body["total"] == 3

    assert body["items"] == [
        {
            "code": "PT",
            "name": "Portugal",
            "alpha3_code": "PRT",
        },
        {
            "code": "ES",
            "name": "Spain",
            "alpha3_code": "ESP",
        },
        {
            "code": "LK",
            "name": "Sri Lanka",
            "alpha3_code": "LKA",
        },
    ]


def test_mobile_user_can_list_countries(
    countries_client: TestClient,
) -> None:
    headers = mobile_headers(countries_client)

    response = countries_client.get(
        "/api/v1/countries",
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["total"] == 3


def test_web_user_can_get_country(
    countries_client: TestClient,
) -> None:
    web_login(countries_client)

    response = countries_client.get("/api/v1/countries/PT")

    assert response.status_code == 200
    assert response.json() == {
        "code": "PT",
        "name": "Portugal",
        "alpha3_code": "PRT",
    }


def test_country_code_is_case_insensitive(
    countries_client: TestClient,
) -> None:
    web_login(countries_client)

    response = countries_client.get("/api/v1/countries/pt")

    assert response.status_code == 200
    assert response.json()["code"] == "PT"


def test_unknown_country_returns_404(
    countries_client: TestClient,
) -> None:
    web_login(countries_client)

    response = countries_client.get("/api/v1/countries/ZZ")

    assert response.status_code == 404
    assert response.json()["detail"] == "Country not found."


def test_invalid_bearer_does_not_fallback_to_web_cookie(
    countries_client: TestClient,
) -> None:
    web_login(countries_client)

    response = countries_client.get(
        "/api/v1/countries",
        headers={
            "Authorization": "Bearer invalid-token",
        },
    )

    assert response.status_code == 401


def test_unsupported_authorization_scheme_is_rejected(
    countries_client: TestClient,
) -> None:
    web_login(countries_client)

    response = countries_client.get(
        "/api/v1/countries",
        headers={
            "Authorization": "Basic invalid",
        },
    )

    assert response.status_code == 401


def test_revoked_web_session_cannot_list_countries(
    countries_client: TestClient,
) -> None:
    web_login(countries_client)

    credential = countries_client.cookies.get("beenaround_session")
    assert credential is not None

    response = countries_client.post(
        "/api/v1/auth/logout",
        headers={"Origin": "http://testserver"},
    )
    assert response.status_code == 204

    countries_client.cookies.set("beenaround_session", credential)

    response = countries_client.get("/api/v1/countries")

    assert response.status_code == 401


def test_revoked_web_session_cannot_list_countries(
    countries_client: TestClient,
) -> None:
    web_login(countries_client)

    credential = countries_client.cookies.get("beenaround_session")
    assert credential is not None

    logout_response = countries_client.post(
        "/api/v1/auth/logout",
        headers={"Origin": "http://testserver"},
    )

    assert logout_response.status_code == 204

    # Simulate a client attempting to reuse its revoked session.
    countries_client.cookies.set("beenaround_session", credential)

    response = countries_client.get("/api/v1/countries")

    assert response.status_code == 401


def test_revoked_mobile_session_cannot_list_countries(
    countries_client: TestClient,
) -> None:
    login_response = countries_client.post(
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

    # The access token must work before logout.
    before_logout = countries_client.get(
        "/api/v1/countries",
        headers=headers,
    )

    assert before_logout.status_code == 200

    # Revoke the Mobile session using its refresh token.
    logout_response = countries_client.post(
        "/api/v1/auth/mobile/logout",
        json={
            "refresh_token": tokens["refresh_token"],
        },
    )

    assert logout_response.status_code == 204

    # The previously issued access token must now be rejected.
    after_logout = countries_client.get(
        "/api/v1/countries",
        headers=headers,
    )

    assert after_logout.status_code == 401
