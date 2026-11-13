"""Tests for the authenticated airline catalog API."""

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
from app.models.airline import Airline
from app.models.user import User


TEST_PASSWORD = "correct-password-123"


@pytest.fixture
def airlines_client(tmp_path: Path) -> Generator[TestClient, None, None]:
    engine = create_database_engine(f"sqlite:///{tmp_path / 'airlines_api.db'}")

    Base.metadata.create_all(engine)

    with Session(engine) as session:
        session.add_all(
            [
                Airline(
                    id=100,
                    name="TAP Air Portugal",
                    iata_code="TP",
                    icao_code="TAP",
                    callsign="AIR PORTUGAL",
                    country_name="Portugal",
                    source_key="test:tap",
                ),
                Airline(
                    id=101,
                    name="Ryanair",
                    iata_code="FR",
                    icao_code="RYR",
                    callsign="RYANAIR",
                    country_name="Ireland",
                    source_key="test:ryanair",
                ),
                Airline(
                    id=102,
                    name="British Airways",
                    iata_code="BA",
                    icao_code="BAW",
                    callsign="SPEEDBIRD",
                    country_name="United Kingdom",
                    source_key="test:british-airways",
                ),
                Airline(
                    id=103,
                    name="TAP Regional",
                    iata_code=None,
                    icao_code=None,
                    callsign=None,
                    country_name="Portugal",
                    source_key="test:tap-regional",
                ),
                Airline(
                    id=104,
                    name="TAP Historic Airways",
                    iata_code=None,
                    icao_code="TAP",
                    callsign=None,
                    country_name="Portugal",
                    source_key="test:tap-historic",
                ),
                Airline(
                    id=105,
                    name="100% Aviation",
                    iata_code=None,
                    icao_code=None,
                    callsign=None,
                    country_name=None,
                    source_key="test:percent",
                ),
                Airline(
                    id=106,
                    name="Royal Air Transport",
                    iata_code=None,
                    icao_code=None,
                    callsign="ROYAL AIR",
                    country_name=None,
                    source_key="test:royal",
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


def test_airline_search_requires_authentication(
    airlines_client: TestClient,
) -> None:
    response = airlines_client.get("/api/v1/airlines?q=TAP")

    assert response.status_code == 401


def test_airline_details_require_authentication(
    airlines_client: TestClient,
) -> None:
    response = airlines_client.get("/api/v1/airlines/100")

    assert response.status_code == 401


def test_web_user_can_search_airlines(
    airlines_client: TestClient,
) -> None:
    web_login(airlines_client)

    response = airlines_client.get("/api/v1/airlines?q=TP")

    assert response.status_code == 200

    body = response.json()

    assert body["items"][0] == {
        "id": 100,
        "name": "TAP Air Portugal",
        "iata_code": "TP",
        "icao_code": "TAP",
        "callsign": "AIR PORTUGAL",
        "country_name": "Portugal",
    }

    assert body["limit"] == 20
    assert body["offset"] == 0


def test_mobile_user_can_search_airlines(
    airlines_client: TestClient,
) -> None:
    headers = mobile_headers(airlines_client)

    response = airlines_client.get(
        "/api/v1/airlines?q=FR",
        headers=headers,
    )

    assert response.status_code == 200

    assert response.json()["items"][0]["id"] == 101


def test_exact_iata_match_has_priority(
    airlines_client: TestClient,
) -> None:
    web_login(airlines_client)

    response = airlines_client.get("/api/v1/airlines?q=TP")

    assert response.status_code == 200

    assert response.json()["items"][0]["id"] == 100


def test_search_by_icao_returns_multiple_matches(
    airlines_client: TestClient,
) -> None:
    web_login(airlines_client)

    response = airlines_client.get("/api/v1/airlines?q=TAP")

    assert response.status_code == 200

    ids = [item["id"] for item in response.json()["items"]]

    assert 100 in ids
    assert 103 in ids
    assert 104 in ids


def test_search_by_name(
    airlines_client: TestClient,
) -> None:
    web_login(airlines_client)

    response = airlines_client.get("/api/v1/airlines?q=Ryanair")

    assert response.status_code == 200
    assert response.json()["items"][0]["id"] == 101


def test_search_by_callsign(
    airlines_client: TestClient,
) -> None:
    web_login(airlines_client)

    response = airlines_client.get("/api/v1/airlines?q=SPEEDBIRD")

    assert response.status_code == 200
    assert response.json()["items"][0]["id"] == 102


def test_search_is_case_insensitive(
    airlines_client: TestClient,
) -> None:
    web_login(airlines_client)

    uppercase = airlines_client.get("/api/v1/airlines?q=TAP")
    lowercase = airlines_client.get("/api/v1/airlines?q=tap")

    assert uppercase.status_code == 200
    assert lowercase.status_code == 200

    assert uppercase.json()["items"] == lowercase.json()["items"]


def test_search_treats_wildcards_as_literal_text(
    airlines_client: TestClient,
) -> None:
    web_login(airlines_client)

    response = airlines_client.get(
        "/api/v1/airlines",
        params={"q": "%"},
    )

    assert response.status_code == 200

    body = response.json()

    assert body["total"] == 1
    assert body["items"][0]["id"] == 105


def test_search_returns_paginated_results(
    airlines_client: TestClient,
) -> None:
    web_login(airlines_client)

    response = airlines_client.get("/api/v1/airlines?q=TAP&limit=2&offset=1")

    assert response.status_code == 200

    body = response.json()

    assert body["total"] == 3
    assert body["limit"] == 2
    assert body["offset"] == 1
    assert len(body["items"]) == 2


def test_get_airline_details(
    airlines_client: TestClient,
) -> None:
    web_login(airlines_client)

    response = airlines_client.get("/api/v1/airlines/100")

    assert response.status_code == 200

    assert response.json() == {
        "id": 100,
        "name": "TAP Air Portugal",
        "iata_code": "TP",
        "icao_code": "TAP",
        "callsign": "AIR PORTUGAL",
        "country_name": "Portugal",
    }


def test_get_unknown_airline_returns_404(
    airlines_client: TestClient,
) -> None:
    web_login(airlines_client)

    response = airlines_client.get("/api/v1/airlines/999999")

    assert response.status_code == 404


def test_search_without_query_lists_airlines(
    airlines_client: TestClient,
) -> None:
    web_login(airlines_client)

    response = airlines_client.get("/api/v1/airlines")

    assert response.status_code == 200

    data = response.json()

    assert "items" in data
    assert "total" in data
    assert data["limit"] == 20
    assert data["offset"] == 0

    names = [item["name"] for item in data["items"]]

    assert names == sorted(names, key=str.casefold)


def test_blank_query_returns_422(
    airlines_client: TestClient,
) -> None:
    web_login(airlines_client)

    response = airlines_client.get(
        "/api/v1/airlines",
        params={"q": "   "},
    )

    assert response.status_code == 422


@pytest.mark.parametrize(
    "query",
    [
        "limit=0",
        "limit=101",
        "offset=-1",
    ],
)
def test_invalid_pagination_returns_422(
    airlines_client: TestClient,
    query: str,
) -> None:
    web_login(airlines_client)

    response = airlines_client.get(f"/api/v1/airlines?q=TAP&{query}")

    assert response.status_code == 422
