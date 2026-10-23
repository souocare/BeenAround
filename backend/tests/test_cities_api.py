"""Tests for the authenticated city catalog search API."""

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
from app.models.city import City
from app.models.country import Country
from app.models.user import User

TEST_PASSWORD = "correct-password-123"


@pytest.fixture
def cities_client(tmp_path: Path) -> Generator[TestClient, None, None]:
    engine = create_database_engine(f"sqlite:///{tmp_path / 'cities_api.db'}")

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
                    code="FR",
                    name="France",
                    alpha3_code="FRA",
                    continent="Europe",
                ),
                Country(
                    code="BR",
                    name="Brazil",
                    alpha3_code="BRA",
                    continent="South America",
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
                City(
                    id=100,
                    country_code="PT",
                    name="Lisbon",
                    ascii_name="Lisbon",
                    latitude=38.72,
                    longitude=-9.14,
                    population=517802,
                    feature_code="PPLC",
                ),
                City(
                    id=101,
                    country_code="US",
                    name="Lisbon",
                    ascii_name="Lisbon",
                    latitude=40.0,
                    longitude=-80.0,
                    population=9000,
                    feature_code="PPL",
                ),
                City(
                    id=102,
                    country_code="PT",
                    name="Porto",
                    ascii_name="Porto",
                    latitude=41.15,
                    longitude=-8.61,
                    population=252687,
                    feature_code="PPLA",
                ),
                City(
                    id=103,
                    country_code="PT",
                    name="Porto Salvo",
                    ascii_name="Porto Salvo",
                    latitude=38.72,
                    longitude=-9.30,
                    population=13867,
                    feature_code="PPL",
                ),
                City(
                    id=104,
                    country_code="FR",
                    name="Paris",
                    ascii_name="Paris",
                    latitude=48.86,
                    longitude=2.35,
                    population=2138551,
                    feature_code="PPLC",
                ),
                City(
                    id=105,
                    country_code="BR",
                    name="São Paulo",
                    ascii_name="Sao Paulo",
                    latitude=-23.55,
                    longitude=-46.63,
                    population=12400232,
                    feature_code="PPLA",
                ),
                City(
                    id=106,
                    country_code="PT",
                    name="Porto Novo",
                    ascii_name="Porto Novo",
                    latitude=39.0,
                    longitude=-9.0,
                    population=1000,
                    feature_code="PPL",
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


def test_cities_requires_authentication(cities_client: TestClient) -> None:
    response = cities_client.get("/api/v1/cities?q=Lisbon")

    assert response.status_code == 401


def test_web_user_can_search_cities(cities_client: TestClient) -> None:
    web_login(cities_client)

    response = cities_client.get("/api/v1/cities?q=Lisbon")

    assert response.status_code == 200

    body = response.json()

    assert body["total"] == 2
    assert body["limit"] == 20
    assert body["offset"] == 0
    assert [item["id"] for item in body["items"]] == [100, 101]

    assert body["items"][0] == {
        "id": 100,
        "name": "Lisbon",
        "ascii_name": "Lisbon",
        "country_code": "PT",
        "country_name": "Portugal",
        "latitude": 38.72,
        "longitude": -9.14,
        "population": 517802,
        "feature_code": "PPLC",
    }


def test_mobile_user_can_search_cities(cities_client: TestClient) -> None:
    headers = mobile_headers(cities_client)

    response = cities_client.get(
        "/api/v1/cities?q=Paris",
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["items"][0]["name"] == "Paris"


def test_country_filter(cities_client: TestClient) -> None:
    web_login(cities_client)

    response = cities_client.get(
        "/api/v1/cities?q=Lisbon&country_code=PT"
    )

    assert response.status_code == 200
    assert response.json()["total"] == 1
    assert response.json()["items"][0]["country_code"] == "PT"


def test_country_filter_is_case_insensitive(
    cities_client: TestClient,
) -> None:
    web_login(cities_client)

    response = cities_client.get(
        "/api/v1/cities?q=Porto&country_code=pt"
    )

    assert response.status_code == 200
    assert response.json()["total"] == 3


def test_country_filter_without_query(cities_client: TestClient) -> None:
    web_login(cities_client)

    response = cities_client.get("/api/v1/cities?country_code=PT")

    assert response.status_code == 200
    assert response.json()["total"] == 4


def test_search_is_case_insensitive(cities_client: TestClient) -> None:
    web_login(cities_client)

    response = cities_client.get("/api/v1/cities?q=lisbon")

    assert response.status_code == 200
    assert response.json()["total"] == 2


def test_ascii_search_finds_accented_city(
    cities_client: TestClient,
) -> None:
    web_login(cities_client)

    response = cities_client.get("/api/v1/cities?q=Sao")

    assert response.status_code == 200
    assert response.json()["total"] == 1
    assert response.json()["items"][0]["name"] == "São Paulo"


def test_exact_match_precedes_prefix_match(
    cities_client: TestClient,
) -> None:
    web_login(cities_client)

    response = cities_client.get("/api/v1/cities?q=Porto")

    assert response.status_code == 200

    names = [item["name"] for item in response.json()["items"]]

    assert names[0] == "Porto"
    assert set(names[1:]) == {"Porto Salvo", "Porto Novo"}


def test_prefix_matches_are_sorted_by_population(
    cities_client: TestClient,
) -> None:
    web_login(cities_client)

    response = cities_client.get("/api/v1/cities?q=Porto")

    assert response.status_code == 200

    names = [item["name"] for item in response.json()["items"]]

    assert names == ["Porto", "Porto Salvo", "Porto Novo"]


def test_pagination(cities_client: TestClient) -> None:
    web_login(cities_client)

    response = cities_client.get(
        "/api/v1/cities?q=Porto&limit=1&offset=1"
    )

    assert response.status_code == 200

    body = response.json()

    assert body["total"] == 3
    assert body["limit"] == 1
    assert body["offset"] == 1
    assert len(body["items"]) == 1
    assert body["items"][0]["name"] == "Porto Salvo"


@pytest.mark.parametrize(
    "query",
    [
        "",
        "   ",
    ],
)
def test_empty_query_without_country_is_rejected(
    cities_client: TestClient,
    query: str,
) -> None:
    web_login(cities_client)

    response = cities_client.get(
        "/api/v1/cities",
        params={"q": query},
    )

    assert response.status_code == 422


def test_missing_query_and_country_is_rejected(
    cities_client: TestClient,
) -> None:
    web_login(cities_client)

    response = cities_client.get("/api/v1/cities")

    assert response.status_code == 422


@pytest.mark.parametrize(
    ("params", "expected_status"),
    [
        ({"q": "Lisbon", "limit": 0}, 422),
        ({"q": "Lisbon", "limit": 101}, 422),
        ({"q": "Lisbon", "offset": -1}, 422),
        ({"q": "Lisbon", "country_code": "P"}, 422),
        ({"q": "Lisbon", "country_code": "PRT"}, 422),
    ],
)
def test_invalid_parameters(
    cities_client: TestClient,
    params: dict,
    expected_status: int,
) -> None:
    web_login(cities_client)

    response = cities_client.get(
        "/api/v1/cities",
        params=params,
    )

    assert response.status_code == expected_status


def test_unknown_country_returns_empty_results(
    cities_client: TestClient,
) -> None:
    web_login(cities_client)

    response = cities_client.get(
        "/api/v1/cities?country_code=ZZ"
    )

    assert response.status_code == 200
    assert response.json()["total"] == 0
    assert response.json()["items"] == []


def test_invalid_bearer_does_not_fallback_to_cookie(
    cities_client: TestClient,
) -> None:
    web_login(cities_client)

    response = cities_client.get(
        "/api/v1/cities?q=Lisbon",
        headers={"Authorization": "Bearer invalid-token"},
    )

    assert response.status_code == 401


def test_unsupported_authorization_scheme_is_rejected(
    cities_client: TestClient,
) -> None:
    web_login(cities_client)

    response = cities_client.get(
        "/api/v1/cities?q=Lisbon",
        headers={"Authorization": "Basic invalid"},
    )

    assert response.status_code == 401


@pytest.mark.parametrize("query", ["%", "_", "\\"])
def test_search_treats_sql_wildcards_as_literals(
    cities_client: TestClient,
    query: str,
) -> None:
    web_login(cities_client)

    response = cities_client.get(
        "/api/v1/cities",
        params={"q": query},
    )

    assert response.status_code == 200
    assert response.json()["total"] == 0
    assert response.json()["items"] == []