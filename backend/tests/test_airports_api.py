"""Tests for the authenticated airport catalog API."""

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
from app.models.airport import Airport
from app.models.country import Country
from app.models.user import User


TEST_PASSWORD = "correct-password-123"


@pytest.fixture
def airports_client(tmp_path: Path) -> Generator[TestClient, None, None]:
    """Create an isolated API client with a small airport catalog."""

    engine = create_database_engine(f"sqlite:///{tmp_path / 'airports_api.db'}")

    Base.metadata.create_all(engine)

    with Session(engine) as session:
        session.add_all(
            [
                Country(
                    code="PT",
                    name="Portugal",
                    alpha3_code="PRT",
                    continent="Europe",
                ),
                Country(
                    code="GB",
                    name="United Kingdom",
                    alpha3_code="GBR",
                    continent="Europe",
                ),
                Country(
                    code="US",
                    name="United States",
                    alpha3_code="USA",
                    continent="North America",
                ),
            ]
        )

        session.flush()

        session.add_all(
            [
                Airport(
                    id=100,
                    ident="LPPT",
                    iata_code="LIS",
                    icao_code="LPPT",
                    name="Lisbon Humberto Delgado Airport",
                    municipality="Lisbon",
                    source_country_code="PT",
                    country_code="PT",
                    latitude=38.77,
                    longitude=-9.13,
                    type="large_airport",
                    scheduled_service=True,
                ),
                Airport(
                    id=101,
                    ident="LPPR",
                    iata_code="OPO",
                    icao_code="LPPR",
                    name="Francisco de Sá Carneiro Airport",
                    municipality="Porto",
                    source_country_code="PT",
                    country_code="PT",
                    latitude=41.24,
                    longitude=-8.68,
                    type="large_airport",
                    scheduled_service=True,
                ),
                Airport(
                    id=102,
                    ident="EGLL",
                    iata_code="LHR",
                    icao_code="EGLL",
                    name="London Heathrow Airport",
                    municipality="London",
                    source_country_code="GB",
                    country_code="GB",
                    latitude=51.47,
                    longitude=-0.45,
                    type="large_airport",
                    scheduled_service=True,
                ),
                Airport(
                    id=103,
                    ident="KJFK",
                    iata_code="JFK",
                    icao_code="KJFK",
                    name="John F. Kennedy International Airport",
                    municipality="New York",
                    source_country_code="US",
                    country_code="US",
                    latitude=40.64,
                    longitude=-73.78,
                    type="large_airport",
                    scheduled_service=True,
                ),
                Airport(
                    id=104,
                    ident="PT-0001",
                    iata_code=None,
                    icao_code=None,
                    name="Lisbon Regional Airfield",
                    municipality="Lisbon",
                    source_country_code="PT",
                    country_code="PT",
                    latitude=38.75,
                    longitude=-9.20,
                    type="small_airport",
                    scheduled_service=False,
                ),
                Airport(
                    id=105,
                    ident="PT-0002",
                    iata_code=None,
                    icao_code=None,
                    name="Lisbon Private Aerodrome",
                    municipality="Lisbon",
                    source_country_code="PT",
                    country_code="PT",
                    latitude=38.80,
                    longitude=-9.25,
                    type="small_airport",
                    scheduled_service=False,
                ),
                Airport(
                    id=106,
                    ident="XK-0001",
                    iata_code=None,
                    icao_code=None,
                    name="Kosovo Regional Airport",
                    municipality="Pristina",
                    source_country_code="XK",
                    country_code=None,
                    latitude=42.57,
                    longitude=21.03,
                    type="small_airport",
                    scheduled_service=False,
                ),
                Airport(
                    id=107,
                    ident="PT-0003",
                    iata_code=None,
                    icao_code=None,
                    name="Lisbon Historic Airfield",
                    municipality="Lisbon",
                    source_country_code="PT",
                    country_code="PT",
                    latitude=None,
                    longitude=None,
                    type="closed",
                    scheduled_service=False,
                ),
                Airport(
                    id=108,
                    ident="PT-0004",
                    iata_code=None,
                    icao_code=None,
                    name="100% Lisbon Airfield",
                    municipality="Lisbon",
                    source_country_code="PT",
                    country_code="PT",
                    latitude=38.70,
                    longitude=-9.30,
                    type="small_airport",
                    scheduled_service=False,
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


def test_airport_search_requires_authentication(
    airports_client: TestClient,
) -> None:
    response = airports_client.get("/api/v1/airports?q=LIS")

    assert response.status_code == 401


def test_airport_details_require_authentication(
    airports_client: TestClient,
) -> None:
    response = airports_client.get("/api/v1/airports/100")

    assert response.status_code == 401


def test_web_user_can_search_airports(
    airports_client: TestClient,
) -> None:
    web_login(airports_client)

    response = airports_client.get("/api/v1/airports?q=LIS")

    assert response.status_code == 200

    body = response.json()

    assert body["limit"] == 20
    assert body["offset"] == 0

    assert body["items"][0] == {
        "id": 100,
        "ident": "LPPT",
        "iata_code": "LIS",
        "icao_code": "LPPT",
        "name": "Lisbon Humberto Delgado Airport",
        "municipality": "Lisbon",
        "source_country_code": "PT",
        "country_code": "PT",
        "country_name": "Portugal",
        "latitude": 38.77,
        "longitude": -9.13,
        "type": "large_airport",
        "scheduled_service": True,
        "timezone_id": None,
    }


def test_mobile_user_can_search_airports(
    airports_client: TestClient,
) -> None:
    headers = mobile_headers(airports_client)

    response = airports_client.get(
        "/api/v1/airports?q=OPO",
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["items"][0]["id"] == 101


def test_exact_iata_match_has_priority(
    airports_client: TestClient,
) -> None:
    web_login(airports_client)

    response = airports_client.get("/api/v1/airports?q=LIS")

    assert response.status_code == 200

    # LIS also occurs in Lisbon Regional Airfield and other names.
    # The exact IATA match must remain first.
    assert response.json()["items"][0]["id"] == 100


def test_search_by_icao_code(
    airports_client: TestClient,
) -> None:
    web_login(airports_client)

    response = airports_client.get("/api/v1/airports?q=LPPT")

    assert response.status_code == 200
    assert response.json()["items"][0]["id"] == 100


def test_search_by_ident(
    airports_client: TestClient,
) -> None:
    web_login(airports_client)

    response = airports_client.get("/api/v1/airports?q=PT-0001")

    assert response.status_code == 200
    assert response.json()["items"][0]["id"] == 104


def test_search_by_municipality(
    airports_client: TestClient,
) -> None:
    web_login(airports_client)

    response = airports_client.get("/api/v1/airports?q=Lisbon")

    assert response.status_code == 200

    ids = [item["id"] for item in response.json()["items"]]

    assert 100 in ids
    assert 104 in ids
    assert 105 in ids


def test_search_is_case_insensitive(
    airports_client: TestClient,
) -> None:
    web_login(airports_client)

    uppercase = airports_client.get("/api/v1/airports?q=LPPT")
    lowercase = airports_client.get("/api/v1/airports?q=lppt")

    assert uppercase.status_code == 200
    assert lowercase.status_code == 200

    assert uppercase.json()["items"] == lowercase.json()["items"]


def test_filter_by_country(
    airports_client: TestClient,
) -> None:
    web_login(airports_client)

    response = airports_client.get("/api/v1/airports?country_code=PT")

    assert response.status_code == 200

    body = response.json()

    assert body["total"] == 6

    assert all(item["country_code"] == "PT" for item in body["items"])


def test_scheduled_only_excludes_unscheduled_airports(
    airports_client: TestClient,
) -> None:
    web_login(airports_client)

    response = airports_client.get("/api/v1/airports?q=Lisbon&scheduled_only=true")

    assert response.status_code == 200

    ids = [item["id"] for item in response.json()["items"]]

    assert ids == [100]

    assert all(item["scheduled_service"] for item in response.json()["items"])


def test_pagination(
    airports_client: TestClient,
) -> None:
    web_login(airports_client)

    response = airports_client.get("/api/v1/airports?country_code=PT&limit=2&offset=1")

    assert response.status_code == 200

    body = response.json()

    assert body["total"] == 6
    assert body["limit"] == 2
    assert body["offset"] == 1
    assert len(body["items"]) == 2


def test_pagination_order_is_stable(
    airports_client: TestClient,
) -> None:
    web_login(airports_client)

    first = airports_client.get("/api/v1/airports?country_code=PT&limit=2&offset=0")

    second = airports_client.get("/api/v1/airports?country_code=PT&limit=2&offset=2")

    assert first.status_code == 200
    assert second.status_code == 200

    first_ids = [item["id"] for item in first.json()["items"]]
    second_ids = [item["id"] for item in second.json()["items"]]

    assert not set(first_ids).intersection(second_ids)


def test_search_treats_wildcards_as_literal_text(
    airports_client: TestClient,
) -> None:
    web_login(airports_client)

    response = airports_client.get(
        "/api/v1/airports",
        params={"q": "%"},
    )

    assert response.status_code == 200

    body = response.json()

    assert body["total"] == 1
    assert body["items"][0]["id"] == 108


def test_unknown_country_does_not_hide_airport(
    airports_client: TestClient,
) -> None:
    web_login(airports_client)

    response = airports_client.get("/api/v1/airports?q=Kosovo")

    assert response.status_code == 200

    body = response.json()

    assert body["total"] == 1

    airport = body["items"][0]

    assert airport["id"] == 106
    assert airport["source_country_code"] == "XK"
    assert airport["country_code"] is None
    assert airport["country_name"] is None


def test_get_airport_details(
    airports_client: TestClient,
) -> None:
    web_login(airports_client)

    response = airports_client.get("/api/v1/airports/100")

    assert response.status_code == 200

    airport = response.json()

    assert airport["id"] == 100
    assert airport["iata_code"] == "LIS"
    assert airport["icao_code"] == "LPPT"
    assert airport["country_name"] == "Portugal"


def test_get_airport_with_unknown_country(
    airports_client: TestClient,
) -> None:
    web_login(airports_client)

    response = airports_client.get("/api/v1/airports/106")

    assert response.status_code == 200

    airport = response.json()

    assert airport["source_country_code"] == "XK"
    assert airport["country_code"] is None
    assert airport["country_name"] is None


def test_get_airport_without_coordinates(
    airports_client: TestClient,
) -> None:
    web_login(airports_client)

    response = airports_client.get("/api/v1/airports/107")

    assert response.status_code == 200

    airport = response.json()

    assert airport["latitude"] is None
    assert airport["longitude"] is None


def test_get_unknown_airport_returns_404(
    airports_client: TestClient,
) -> None:
    web_login(airports_client)

    response = airports_client.get("/api/v1/airports/999999")

    assert response.status_code == 404


def test_search_without_filters_returns_422(
    airports_client: TestClient,
) -> None:
    web_login(airports_client)

    response = airports_client.get("/api/v1/airports")

    assert response.status_code == 422


def test_blank_query_returns_422(
    airports_client: TestClient,
) -> None:
    web_login(airports_client)

    response = airports_client.get(
        "/api/v1/airports",
        params={"q": "   "},
    )

    assert response.status_code == 422


@pytest.mark.parametrize(
    "query",
    [
        "limit=0",
        "limit=101",
        "offset=-1",
        "country_code=P",
    ],
)
def test_invalid_search_parameters_return_422(
    airports_client: TestClient,
    query: str,
) -> None:
    web_login(airports_client)

    response = airports_client.get(f"/api/v1/airports?q=LIS&{query}")

    assert response.status_code == 422
