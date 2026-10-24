"""Integration tests for the city visits REST API."""

from collections.abc import Generator
from datetime import date
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
from app.models.city_visit import CityVisit
from app.models.country import Country
from app.models.user import User


TEST_PASSWORD = "correct-password-123"
LISBON_ID = 2267057
MADRID_ID = 3117735
ORIGIN = {"Origin": "http://testserver"}

BASE_URL = "/api/v1/city-visits"


@pytest.fixture
def visits_client(tmp_path: Path) -> Generator[TestClient, None, None]:
    engine = create_database_engine(f"sqlite:///{tmp_path / 'city_visits_api.db'}")

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
                    code="ES",
                    name="Spain",
                    alpha3_code="ESP",
                    continent="Europe",
                ),
            ]
        )
        session.flush()

        session.add_all(
            [
                City(
                    id=LISBON_ID,
                    country_code="PT",
                    name="Lisbon",
                    ascii_name="Lisbon",
                    latitude=38.71667,
                    longitude=-9.13333,
                    population=517802,
                    feature_code="PPLC",
                ),
                City(
                    id=MADRID_ID,
                    country_code="ES",
                    name="Madrid",
                    ascii_name="Madrid",
                    latitude=40.4165,
                    longitude=-3.70256,
                    population=3255944,
                    feature_code="PPLC",
                ),
            ]
        )

        first_user = User(
            username="goncalo",
            email="goncalo@example.com",
            display_name="Gonçalo",
            password_hash=hash_password(TEST_PASSWORD),
        )
        second_user = User(
            username="anotheruser",
            email="another@example.com",
            display_name="Another User",
            password_hash=hash_password(TEST_PASSWORD),
        )

        session.add_all([first_user, second_user])
        session.flush()

        session.add_all(
            [
                CityVisit(
                    user_id=first_user.id,
                    city_id=LISBON_ID,
                    started_on=date(2025, 7, 10),
                    ended_on=date(2025, 7, 15),
                ),
                CityVisit(
                    user_id=first_user.id,
                    city_id=LISBON_ID,
                    started_on=date(2026, 2, 1),
                    ended_on=date(2026, 2, 5),
                ),
                CityVisit(
                    user_id=first_user.id,
                    city_id=MADRID_ID,
                ),
                CityVisit(
                    user_id=second_user.id,
                    city_id=MADRID_ID,
                    started_on=date(2024, 8, 1),
                    ended_on=date(2024, 8, 10),
                ),
            ]
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


def login_web(client: TestClient, username: str = "goncalo") -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={"login": username, "password": TEST_PASSWORD},
    )
    assert response.status_code == 200


def login_mobile(
    client: TestClient,
    username: str = "goncalo",
) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/mobile/login",
        json={"login": username, "password": TEST_PASSWORD},
    )
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def create_visit(
    client: TestClient,
    *,
    city_id: int = LISBON_ID,
    started_on: str | None = None,
    ended_on: str | None = None,
) -> str:
    response = client.post(
        BASE_URL,
        json={
            "city_id": city_id,
            "started_on": started_on,
            "ended_on": ended_on,
        },
        headers=ORIGIN,
    )
    assert response.status_code == 201
    return response.json()["id"]


def test_listing_requires_authentication(visits_client: TestClient) -> None:
    assert visits_client.get(BASE_URL).status_code == 401


def test_web_user_lists_only_own_visits(visits_client: TestClient) -> None:
    login_web(visits_client)

    response = visits_client.get(BASE_URL)

    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 3
    assert len(body["items"]) == 3
    assert sorted(item["city_id"] for item in body["items"]) == [
        LISBON_ID,
        LISBON_ID,
        MADRID_ID,
    ]
    assert all("user_id" not in item for item in body["items"])


def test_mobile_user_can_list_visits(visits_client: TestClient) -> None:
    headers = login_mobile(visits_client)

    response = visits_client.get(BASE_URL, headers=headers)

    assert response.status_code == 200
    assert response.json()["total"] == 3


def test_second_user_only_sees_own_visits(visits_client: TestClient) -> None:
    login_web(visits_client, "anotheruser")

    response = visits_client.get(BASE_URL)

    assert response.status_code == 200
    assert response.json()["total"] == 1
    assert response.json()["items"][0]["city_id"] == MADRID_ID


def test_repeated_city_visits_are_preserved(visits_client: TestClient) -> None:
    login_web(visits_client)

    response = visits_client.get(BASE_URL)

    lisbon_visits = [item for item in response.json()["items"] if item["city_id"] == LISBON_ID]

    assert len(lisbon_visits) == 2
    assert {item["started_on"] for item in lisbon_visits} == {
        "2025-07-10",
        "2026-02-01",
    }


def test_listing_includes_city_and_country_details(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.get(BASE_URL)

    assert response.status_code == 200

    lisbon = next(item for item in response.json()["items"] if item["city_id"] == LISBON_ID)

    assert lisbon["city_name"] == "Lisbon"
    assert lisbon["country_code"] == "PT"
    assert lisbon["country_name"] == "Portugal"

    assert set(lisbon) == {
        "id",
        "city_id",
        "city_name",
        "country_code",
        "country_name",
        "started_on",
        "ended_on",
        "created_at",
        "updated_at",
    }


def test_undated_visits_are_supported(visits_client: TestClient) -> None:
    login_web(visits_client)

    response = visits_client.get(BASE_URL)

    undated = [item for item in response.json()["items"] if item["started_on"] is None]

    assert len(undated) == 1
    assert undated[0]["ended_on"] is None


def test_create_city_visit(visits_client: TestClient) -> None:
    login_web(visits_client)

    response = visits_client.post(
        BASE_URL,
        json={
            "city_id": LISBON_ID,
            "started_on": "2026-09-28",
            "ended_on": "2026-10-03",
        },
        headers=ORIGIN,
    )

    assert response.status_code == 201

    body = response.json()
    assert body["city_id"] == LISBON_ID
    assert body["city_name"] == "Lisbon"
    assert body["country_code"] == "PT"
    assert body["country_name"] == "Portugal"
    assert body["started_on"] == "2026-09-28"
    assert body["ended_on"] == "2026-10-03"
    assert "user_id" not in body


def test_create_without_dates(visits_client: TestClient) -> None:
    login_web(visits_client)

    visit_id = create_visit(visits_client)

    listing = visits_client.get(BASE_URL)
    visit = next(item for item in listing.json()["items"] if item["id"] == visit_id)

    assert visit["started_on"] is None
    assert visit["ended_on"] is None


@pytest.mark.parametrize(
    "payload",
    [
        {"city_id": 999999999},
        {"city_id": 999999998},
    ],
)
def test_create_unknown_city_returns_404(
    visits_client: TestClient,
    payload: dict,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        BASE_URL,
        json=payload,
        headers=ORIGIN,
    )

    assert response.status_code == 404


@pytest.mark.parametrize(
    "payload",
    [
        {"city_id": LISBON_ID, "ended_on": "2026-10-03"},
        {
            "city_id": LISBON_ID,
            "started_on": "2026-10-05",
            "ended_on": "2026-10-03",
        },
        {"city_id": 0},
        {"city_id": -1},
        {"city_id": None},
        {"city_id": LISBON_ID, "user_id": "forbidden"},
    ],
)
def test_create_rejects_invalid_payload(
    visits_client: TestClient,
    payload: dict,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        BASE_URL,
        json=payload,
        headers=ORIGIN,
    )

    assert response.status_code == 422


def test_create_requires_authentication(visits_client: TestClient) -> None:
    response = visits_client.post(
        BASE_URL,
        json={"city_id": LISBON_ID},
    )
    assert response.status_code == 401


def test_mobile_user_can_create_visit(visits_client: TestClient) -> None:
    headers = login_mobile(visits_client)

    response = visits_client.post(
        BASE_URL,
        json={"city_id": LISBON_ID},
        headers=headers,
    )

    assert response.status_code == 201


def test_create_rejects_external_origin(visits_client: TestClient) -> None:
    login_web(visits_client)

    response = visits_client.post(
        BASE_URL,
        json={"city_id": LISBON_ID},
        headers={"Origin": "https://evil.example"},
    )

    assert response.status_code == 403


def test_update_city_visit(visits_client: TestClient) -> None:
    login_web(visits_client)

    visit_id = create_visit(visits_client)

    response = visits_client.patch(
        f"{BASE_URL}/{visit_id}",
        json={
            "city_id": MADRID_ID,
            "started_on": "2026-09-28",
            "ended_on": "2026-10-03",
        },
        headers=ORIGIN,
    )

    assert response.status_code == 200

    body = response.json()
    assert body["id"] == visit_id
    assert body["city_id"] == MADRID_ID
    assert body["city_name"] == "Madrid"
    assert body["country_code"] == "ES"
    assert body["country_name"] == "Spain"


def test_update_preserves_omitted_fields(visits_client: TestClient) -> None:
    login_web(visits_client)

    visit_id = create_visit(
        visits_client,
        started_on="2026-09-28",
        ended_on="2026-10-03",
    )

    response = visits_client.patch(
        f"{BASE_URL}/{visit_id}",
        json={"city_id": MADRID_ID},
        headers=ORIGIN,
    )

    assert response.status_code == 200
    assert response.json()["started_on"] == "2026-09-28"
    assert response.json()["ended_on"] == "2026-10-03"


def test_update_can_clear_end_date(visits_client: TestClient) -> None:
    login_web(visits_client)

    visit_id = create_visit(
        visits_client,
        started_on="2026-09-28",
        ended_on="2026-10-03",
    )

    response = visits_client.patch(
        f"{BASE_URL}/{visit_id}",
        json={"ended_on": None},
        headers=ORIGIN,
    )

    assert response.status_code == 200
    assert response.json()["ended_on"] is None


@pytest.mark.parametrize(
    "payload",
    [
        {"started_on": "2026-10-05"},
        {"started_on": None},
    ],
)
def test_update_rejects_invalid_final_date_range(
    visits_client: TestClient,
    payload: dict,
) -> None:
    login_web(visits_client)

    visit_id = create_visit(
        visits_client,
        started_on="2026-09-28",
        ended_on="2026-10-03",
    )

    response = visits_client.patch(
        f"{BASE_URL}/{visit_id}",
        json=payload,
        headers=ORIGIN,
    )

    assert response.status_code == 422

    listing = visits_client.get(BASE_URL)
    visit = next(item for item in listing.json()["items"] if item["id"] == visit_id)

    assert visit["started_on"] == "2026-09-28"
    assert visit["ended_on"] == "2026-10-03"


@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"city_id": None},
        {"city_id": 0},
        {"city_id": -1},
        {"user_id": "forbidden"},
    ],
)
def test_update_rejects_invalid_payload(
    visits_client: TestClient,
    payload: dict,
) -> None:
    login_web(visits_client)

    visit_id = create_visit(visits_client)

    response = visits_client.patch(
        f"{BASE_URL}/{visit_id}",
        json=payload,
        headers=ORIGIN,
    )

    assert response.status_code == 422


def test_update_unknown_city_returns_404(visits_client: TestClient) -> None:
    login_web(visits_client)

    visit_id = create_visit(visits_client)

    response = visits_client.patch(
        f"{BASE_URL}/{visit_id}",
        json={"city_id": 999999999},
        headers=ORIGIN,
    )

    assert response.status_code == 404


def test_delete_city_visit(visits_client: TestClient) -> None:
    login_web(visits_client)

    visit_id = create_visit(visits_client)

    response = visits_client.delete(
        f"{BASE_URL}/{visit_id}",
        headers=ORIGIN,
    )

    assert response.status_code == 204
    assert response.content == b""

    listing = visits_client.get(BASE_URL)
    assert all(item["id"] != visit_id for item in listing.json()["items"])


def test_delete_twice_returns_404(visits_client: TestClient) -> None:
    login_web(visits_client)

    visit_id = create_visit(visits_client)

    first = visits_client.delete(
        f"{BASE_URL}/{visit_id}",
        headers=ORIGIN,
    )
    second = visits_client.delete(
        f"{BASE_URL}/{visit_id}",
        headers=ORIGIN,
    )

    assert first.status_code == 204
    assert second.status_code == 404


@pytest.mark.parametrize("method", ["patch", "delete"])
def test_cannot_modify_another_users_visit(
    visits_client: TestClient,
    method: str,
) -> None:
    login_web(visits_client, "anotheruser")

    listing = visits_client.get(BASE_URL)
    other_visit_id = listing.json()["items"][0]["id"]

    visits_client.cookies.clear()
    login_web(visits_client, "goncalo")

    if method == "patch":
        response = visits_client.patch(
            f"{BASE_URL}/{other_visit_id}",
            json={"city_id": LISBON_ID},
            headers=ORIGIN,
        )
    else:
        response = visits_client.delete(
            f"{BASE_URL}/{other_visit_id}",
            headers=ORIGIN,
        )

    assert response.status_code == 404

    visits_client.cookies.clear()
    login_web(visits_client, "anotheruser")

    listing = visits_client.get(BASE_URL)

    assert any(item["id"] == other_visit_id for item in listing.json()["items"])


@pytest.mark.parametrize("method", ["patch", "delete"])
def test_modification_requires_authentication(
    visits_client: TestClient,
    method: str,
) -> None:
    url = f"{BASE_URL}/550e8400-e29b-41d4-a716-446655440000"

    if method == "patch":
        response = visits_client.patch(
            url,
            json={"city_id": LISBON_ID},
        )
    else:
        response = visits_client.delete(url)

    assert response.status_code == 401


@pytest.mark.parametrize("method", ["patch", "delete"])
def test_modification_rejects_external_origin(
    visits_client: TestClient,
    method: str,
) -> None:
    login_web(visits_client)

    visit_id = create_visit(visits_client)
    url = f"{BASE_URL}/{visit_id}"

    if method == "patch":
        response = visits_client.patch(
            url,
            json={"city_id": MADRID_ID},
            headers={"Origin": "https://evil.example"},
        )
    else:
        response = visits_client.delete(
            url,
            headers={"Origin": "https://evil.example"},
        )

    assert response.status_code == 403


@pytest.mark.parametrize("method", ["patch", "delete"])
def test_mobile_user_can_modify_visit(
    visits_client: TestClient,
    method: str,
) -> None:
    login_web(visits_client)
    visit_id = create_visit(visits_client)

    visits_client.cookies.clear()
    headers = login_mobile(visits_client)

    url = f"{BASE_URL}/{visit_id}"

    if method == "patch":
        response = visits_client.patch(
            url,
            json={"city_id": MADRID_ID},
            headers=headers,
        )
        assert response.status_code == 200
    else:
        response = visits_client.delete(url, headers=headers)
        assert response.status_code == 204


@pytest.mark.parametrize("method", ["patch", "delete"])
def test_nonexistent_visit_returns_404(
    visits_client: TestClient,
    method: str,
) -> None:
    login_web(visits_client)

    url = f"{BASE_URL}/550e8400-e29b-41d4-a716-446655440000"

    if method == "patch":
        response = visits_client.patch(
            url,
            json={"city_id": LISBON_ID},
            headers=ORIGIN,
        )
    else:
        response = visits_client.delete(url, headers=ORIGIN)

    assert response.status_code == 404


def test_invalid_bearer_does_not_fallback_to_cookie(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.get(
        BASE_URL,
        headers={"Authorization": "Bearer invalid-token"},
    )

    assert response.status_code == 401


def test_patch_invalid_bearer_does_not_fallback_to_cookie(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    visit_id = create_visit(visits_client)

    response = visits_client.patch(
        f"{BASE_URL}/{visit_id}",
        json={"city_id": MADRID_ID},
        headers={
            "Authorization": "Bearer invalid-token",
            "Origin": "http://testserver",
        },
    )

    assert response.status_code == 401
