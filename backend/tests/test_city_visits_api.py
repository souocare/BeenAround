"""Integration tests for the city visits REST API."""

from collections.abc import Generator
from datetime import date
from pathlib import Path
from unittest.mock import patch

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
from app.repositories.city_visits import CityVisitRepository
from app.schemas.city_visits import CityVisitCreate, CityVisitUpdate

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
                    continent="EU",
                ),
                Country(
                    code="ES",
                    name="Spain",
                    alpha3_code="ESP",
                    continent="EU",
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
                    started_on_precision="day",
                    ended_on=date(2025, 7, 15),
                    ended_on_precision="day",
                ),
                CityVisit(
                    user_id=first_user.id,
                    city_id=LISBON_ID,
                    started_on=date(2026, 2, 1),
                    started_on_precision="day",
                    ended_on=date(2026, 2, 5),
                    ended_on_precision="day",
                ),
                CityVisit(
                    user_id=first_user.id,
                    city_id=MADRID_ID,
                    started_on=date(2025, 3, 10),
                    started_on_precision="day",
                    ended_on=date(2025, 3, 15),
                    ended_on_precision="day",
                ),
                CityVisit(
                    user_id=second_user.id,
                    city_id=MADRID_ID,
                    started_on=date(2024, 8, 1),
                    started_on_precision="day",
                    ended_on=date(2024, 8, 10),
                    ended_on_precision="day",
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
    started_on: str = "2026-09-28",
    ended_on: str = "2026-10-31",
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


def create_country_visit(
    client: TestClient,
    *,
    country_code: str = "PT",
    started_on: str = "2025-06-10",
    ended_on: str = "2025-06-20",
) -> str:
    response = client.post(
        "/api/v1/country-visits",
        json={
            "country_code": country_code,
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
    assert all("country_visit_id" in item for item in body["items"])

    assert all(item["country_visit_id"] is None for item in body["items"])


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
        "country_visit_id",
        "started_on",
        "ended_on",
        "created_at",
        "updated_at",
        "started_on_precision",
        "ended_on_precision",
    }

    assert lisbon["country_visit_id"] is None


def test_listed_city_visits_have_complete_dates(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.get(BASE_URL)

    assert response.status_code == 200

    visits = response.json()["items"]

    assert len(visits) == 3
    assert all(visit["started_on"] is not None for visit in visits)
    assert all(visit["ended_on"] is not None for visit in visits)
    assert all(visit["started_on_precision"] is not None for visit in visits)
    assert all(visit["ended_on_precision"] is not None for visit in visits)


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


def test_create_city_visit_without_dates_is_rejected(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        BASE_URL,
        json={"city_id": LISBON_ID},
        headers=ORIGIN,
    )

    assert response.status_code == 422


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
        json={
            "city_id": LISBON_ID,
            "started_on": "2026-09-28",
            "ended_on": "2026-10-03",
        },
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


def test_update_rejects_clearing_end_date(
    visits_client: TestClient,
) -> None:
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

    assert response.status_code == 422

    listing = visits_client.get(BASE_URL)

    assert listing.status_code == 200

    visit = next(item for item in listing.json()["items"] if item["id"] == visit_id)

    assert visit["started_on"] == "2026-09-28"
    assert visit["started_on_precision"] == "day"
    assert visit["ended_on"] == "2026-10-03"
    assert visit["ended_on_precision"] == "day"


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


@pytest.mark.parametrize(
    ("precision", "input_date", "expected_date"),
    [
        ("day", "2026-09-28", "2026-09-28"),
        ("month", "2026-09-28", "2026-09-01"),
        ("year", "2026-09-28", "2026-01-01"),
    ],
)
def test_create_city_visit_with_partial_start_date(
    visits_client: TestClient,
    precision: str,
    input_date: str,
    expected_date: str,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        BASE_URL,
        json={
            "city_id": LISBON_ID,
            "started_on": input_date,
            "started_on_precision": precision,
            "ended_on": "2026-12-31",
        },
        headers=ORIGIN,
    )

    assert response.status_code == 201

    body = response.json()

    assert body["started_on"] == expected_date
    assert body["started_on_precision"] == precision
    assert body["ended_on"] == "2026-12-31"
    assert body["ended_on_precision"] == "day"

    listing = visits_client.get(BASE_URL)

    assert listing.status_code == 200

    saved = next(item for item in listing.json()["items"] if item["id"] == body["id"])

    assert saved["started_on"] == expected_date
    assert saved["started_on_precision"] == precision


@pytest.mark.parametrize(
    ("precision", "expected_date"),
    [
        ("month", "2026-09-01"),
        ("year", "2026-01-01"),
    ],
)
def test_update_city_visit_precision_only(
    visits_client: TestClient,
    precision: str,
    expected_date: str,
) -> None:
    login_web(visits_client)

    visit_id = create_visit(
        visits_client,
        started_on="2026-09-28",
    )

    response = visits_client.patch(
        f"{BASE_URL}/{visit_id}",
        json={"started_on_precision": precision},
        headers=ORIGIN,
    )

    assert response.status_code == 200
    assert response.json()["started_on"] == expected_date
    assert response.json()["started_on_precision"] == precision


def test_update_city_visit_date_without_precision_defaults_to_day(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        BASE_URL,
        json={
            "city_id": LISBON_ID,
            "started_on": "2026-09-28",
            "started_on_precision": "month",
            "ended_on": "2026-12-31",
        },
        headers=ORIGIN,
    )

    assert response.status_code == 201

    visit_id = response.json()["id"]

    response = visits_client.patch(
        f"{BASE_URL}/{visit_id}",
        json={"started_on": "2026-10-15"},
        headers=ORIGIN,
    )

    assert response.status_code == 200
    assert response.json()["started_on"] == "2026-10-15"
    assert response.json()["started_on_precision"] == "day"


def test_update_city_visit_rejects_clearing_start_date(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    visit_id = create_visit(
        visits_client,
        started_on="2026-09-28",
        ended_on="2026-10-03",
    )

    response = visits_client.patch(
        f"{BASE_URL}/{visit_id}",
        json={"started_on": None},
        headers=ORIGIN,
    )

    assert response.status_code == 422

    listing = visits_client.get(BASE_URL)

    assert listing.status_code == 200

    visit = next(item for item in listing.json()["items"] if item["id"] == visit_id)

    assert visit["started_on"] == "2026-09-28"
    assert visit["started_on_precision"] == "day"
    assert visit["ended_on"] == "2026-10-03"
    assert visit["ended_on_precision"] == "day"


def test_update_city_visit_rejects_precision_increase_without_date(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        BASE_URL,
        json={
            "city_id": LISBON_ID,
            "started_on": "2026-09-28",
            "started_on_precision": "year",
            "ended_on": "2026-12-31",
        },
        headers=ORIGIN,
    )

    assert response.status_code == 201

    visit_id = response.json()["id"]

    response = visits_client.patch(
        f"{BASE_URL}/{visit_id}",
        json={"started_on_precision": "month"},
        headers=ORIGIN,
    )

    assert response.status_code == 422


@pytest.mark.parametrize(
    "payload",
    [
        {
            "city_id": LISBON_ID,
            "started_on_precision": "month",
        },
        {
            "city_id": LISBON_ID,
            "started_on": "2026-09-28",
            "started_on_precision": "invalid",
        },
        {
            "city_id": LISBON_ID,
            "started_on": "2026-09-28",
            "started_on_precision": None,
        },
    ],
)
def test_create_city_visit_rejects_invalid_precision(
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


@pytest.mark.parametrize(
    ("started_on", "started_precision", "ended_on", "ended_precision", "expected_end"),
    [
        ("2026-09-28", "day", "2026-10-15", "month", "2026-10-01"),
        ("2026-01-01", "year", "2026-12-15", "year", "2026-01-01"),
        ("2026-09-28", "day", "2026-09-15", "month", "2026-09-01"),
    ],
)
def test_create_city_visit_with_partial_end_date(
    visits_client: TestClient,
    started_on: str,
    started_precision: str,
    ended_on: str,
    ended_precision: str,
    expected_end: str,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        BASE_URL,
        json={
            "city_id": LISBON_ID,
            "started_on": started_on,
            "started_on_precision": started_precision,
            "ended_on": ended_on,
            "ended_on_precision": ended_precision,
        },
        headers=ORIGIN,
    )

    assert response.status_code == 201

    body = response.json()
    assert body["ended_on"] == expected_end
    assert body["ended_on_precision"] == ended_precision


def test_city_visit_patch_precision_persists(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    visit_id = create_visit(
        visits_client,
        started_on="2026-09-28",
    )

    response = visits_client.patch(
        f"{BASE_URL}/{visit_id}",
        json={"started_on_precision": "month"},
        headers=ORIGIN,
    )

    assert response.status_code == 200

    listing = visits_client.get(BASE_URL)
    assert listing.status_code == 200

    saved = next(item for item in listing.json()["items"] if item["id"] == visit_id)

    assert saved["started_on"] == "2026-09-01"
    assert saved["started_on_precision"] == "month"


def test_create_city_visit_with_existing_country_visit(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    country_response = visits_client.post(
        "/api/v1/country-visits",
        json={
            "country_code": "PT",
            "started_on": "2025-06-10",
            "ended_on": "2025-06-20",
        },
        headers=ORIGIN,
    )

    assert country_response.status_code == 201

    country_visit_id = country_response.json()["id"]

    response = visits_client.post(
        BASE_URL,
        json={
            "city_id": LISBON_ID,
            "started_on": "2025-06-12",
            "ended_on": "2025-06-15",
            "country_visit_id": country_visit_id,
        },
        headers=ORIGIN,
    )

    assert response.status_code == 201
    assert response.json()["country_visit_id"] == country_visit_id


def test_create_city_visit_rejects_different_country(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    country_response = visits_client.post(
        "/api/v1/country-visits",
        json={
            "country_code": "ES",
            "started_on": "2025-06-10",
            "ended_on": "2025-06-20",
        },
        headers=ORIGIN,
    )

    assert country_response.status_code == 201

    response = visits_client.post(
        BASE_URL,
        json={
            "city_id": LISBON_ID,
            "started_on": "2025-06-12",
            "ended_on": "2025-06-15",
            "country_visit_id": country_response.json()["id"],
        },
        headers=ORIGIN,
    )

    assert response.status_code == 422
    assert "same country" in response.json()["detail"]


def test_create_city_visit_rejects_dates_outside_country_visit(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    country_response = visits_client.post(
        "/api/v1/country-visits",
        json={
            "country_code": "PT",
            "started_on": "2025-06-10",
            "ended_on": "2025-06-20",
        },
        headers=ORIGIN,
    )

    assert country_response.status_code == 201

    response = visits_client.post(
        BASE_URL,
        json={
            "city_id": LISBON_ID,
            "started_on": "2025-06-18",
            "ended_on": "2025-06-25",
            "country_visit_id": country_response.json()["id"],
        },
        headers=ORIGIN,
    )

    assert response.status_code == 409

    detail = response.json()["detail"]

    assert detail["code"] == "COUNTRY_VISIT_DATE_EXPANSION_REQUIRED"
    assert detail["country_visit_id"] == country_response.json()["id"]
    assert detail["proposed"]["ended_on"] == "2025-06-25"


def test_create_city_visit_cannot_use_another_users_country_visit(
    visits_client: TestClient,
) -> None:
    """A user cannot associate a city with another user's country visit."""

    # Authenticate as the owner of the country visit.
    owner_headers = login_mobile(visits_client, "anotheruser")

    country_response = visits_client.post(
        "/api/v1/country-visits",
        json={
            "country_code": "PT",
            "started_on": "2025-06-10",
            "ended_on": "2025-06-20",
        },
        headers=owner_headers,
    )

    assert country_response.status_code == 201

    country_visit_id = country_response.json()["id"]

    # Authenticate as a different user.
    other_headers = login_mobile(visits_client, "goncalo")

    response = visits_client.post(
        BASE_URL,
        json={
            "city_id": LISBON_ID,
            "started_on": "2025-06-12",
            "ended_on": "2025-06-15",
            "country_visit_id": country_visit_id,
        },
        headers=other_headers,
    )

    assert response.status_code == 404
    assert response.json()["detail"] == "Country visit not found."


def test_patch_city_visit_can_add_country_association(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    country_visit_id = create_country_visit(visits_client)

    city_visit_id = create_visit(
        visits_client,
        started_on="2025-06-12",
        ended_on="2025-06-15",
    )

    response = visits_client.patch(
        f"{BASE_URL}/{city_visit_id}",
        json={
            "country_visit_id": country_visit_id,
        },
        headers=ORIGIN,
    )

    assert response.status_code == 200
    assert response.json()["country_visit_id"] == country_visit_id

    listed = visits_client.get(BASE_URL)

    assert listed.status_code == 200

    saved = next(item for item in listed.json()["items"] if item["id"] == city_visit_id)

    assert saved["country_visit_id"] == country_visit_id


def test_patch_city_visit_can_remove_country_association(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    country_visit_id = create_country_visit(visits_client)

    city_visit_id = create_visit(
        visits_client,
        started_on="2025-06-12",
        ended_on="2025-06-15",
    )

    associate = visits_client.patch(
        f"{BASE_URL}/{city_visit_id}",
        json={
            "country_visit_id": country_visit_id,
        },
        headers=ORIGIN,
    )

    assert associate.status_code == 200

    response = visits_client.patch(
        f"{BASE_URL}/{city_visit_id}",
        json={
            "country_visit_id": None,
        },
        headers=ORIGIN,
    )

    assert response.status_code == 200
    assert response.json()["country_visit_id"] is None

    # Removing an association must not delete the country visit.
    country_visits = visits_client.get("/api/v1/country-visits")

    assert country_visits.status_code == 200

    assert any(item["id"] == country_visit_id for item in country_visits.json()["items"])


def test_patch_city_visit_preserves_association_when_omitted(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    country_visit_id = create_country_visit(visits_client)

    city_visit_id = create_visit(
        visits_client,
        started_on="2025-06-12",
        ended_on="2025-06-15",
    )

    associate = visits_client.patch(
        f"{BASE_URL}/{city_visit_id}",
        json={
            "country_visit_id": country_visit_id,
        },
        headers=ORIGIN,
    )

    assert associate.status_code == 200

    response = visits_client.patch(
        f"{BASE_URL}/{city_visit_id}",
        json={
            "ended_on": "2025-06-18",
        },
        headers=ORIGIN,
    )

    assert response.status_code == 200

    assert response.json()["country_visit_id"] == country_visit_id
    assert response.json()["ended_on"] == "2025-06-18"


def test_patch_city_visit_rejects_city_from_different_country(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    country_visit_id = create_country_visit(visits_client)

    city_visit_id = create_visit(
        visits_client,
        started_on="2025-06-12",
        ended_on="2025-06-15",
    )

    associate = visits_client.patch(
        f"{BASE_URL}/{city_visit_id}",
        json={
            "country_visit_id": country_visit_id,
        },
        headers=ORIGIN,
    )

    assert associate.status_code == 200

    response = visits_client.patch(
        f"{BASE_URL}/{city_visit_id}",
        json={
            "city_id": MADRID_ID,
        },
        headers=ORIGIN,
    )

    assert response.status_code == 422
    assert "same country" in response.json()["detail"]

    # The rejected change must not modify the persisted visit.
    listed = visits_client.get(BASE_URL)

    saved = next(item for item in listed.json()["items"] if item["id"] == city_visit_id)

    assert saved["city_id"] == LISBON_ID
    assert saved["country_visit_id"] == country_visit_id


def test_patch_city_visit_rejects_dates_outside_country_visit(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    country_visit_id = create_country_visit(visits_client)

    city_visit_id = create_visit(
        visits_client,
        started_on="2025-06-12",
        ended_on="2025-06-15",
    )

    associate = visits_client.patch(
        f"{BASE_URL}/{city_visit_id}",
        json={
            "country_visit_id": country_visit_id,
        },
        headers=ORIGIN,
    )

    assert associate.status_code == 200

    response = visits_client.patch(
        f"{BASE_URL}/{city_visit_id}",
        json={
            "ended_on": "2025-06-25",
        },
        headers=ORIGIN,
    )

    assert response.status_code == 409

    detail = response.json()["detail"]

    assert detail["code"] == "COUNTRY_VISIT_DATE_EXPANSION_REQUIRED"
    assert detail["country_visit_id"] == country_visit_id
    assert detail["current"]["ended_on"] == "2025-06-20"
    assert detail["proposed"]["ended_on"] == "2025-06-25"

    listed = visits_client.get(BASE_URL)

    saved = next(item for item in listed.json()["items"] if item["id"] == city_visit_id)

    assert saved["ended_on"] == "2025-06-15"
    assert saved["country_visit_id"] == country_visit_id


def test_create_city_visit_with_new_country_visit(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        BASE_URL,
        json={
            "city_id": LISBON_ID,
            "started_on": "2025-06-12",
            "ended_on": "2025-06-15",
            "new_country_visit": {
                "started_on": "2025-06-10",
                "ended_on": "2025-06-20",
            },
        },
        headers=ORIGIN,
    )

    assert response.status_code == 201

    city = response.json()

    assert city["country_visit_id"] is not None
    assert city["city_id"] == LISBON_ID
    assert city["country_code"] == "PT"

    countries_response = visits_client.get("/api/v1/country-visits")

    assert countries_response.status_code == 200

    created_country = next(
        item
        for item in countries_response.json()["items"]
        if item["id"] == city["country_visit_id"]
    )

    assert created_country["country_code"] == "PT"
    assert created_country["started_on"] == "2025-06-10"
    assert created_country["ended_on"] == "2025-06-20"

    cities_response = visits_client.get(BASE_URL)

    assert cities_response.status_code == 200

    saved_city = next(item for item in cities_response.json()["items"] if item["id"] == city["id"])

    assert saved_city["country_visit_id"] == created_country["id"]


def test_create_city_visit_rejects_existing_and_new_country_association(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        BASE_URL,
        json={
            "city_id": LISBON_ID,
            "started_on": "2025-06-12",
            "ended_on": "2025-06-15",
            "country_visit_id": "11111111-1111-4111-8111-111111111111",
            "new_country_visit": {
                "started_on": "2025-06-10",
                "ended_on": "2025-06-20",
            },
        },
        headers=ORIGIN,
    )

    assert response.status_code == 422


def test_create_city_with_new_country_rejects_incompatible_dates(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    before_response = visits_client.get("/api/v1/country-visits")

    assert before_response.status_code == 200

    before_ids = {item["id"] for item in before_response.json()["items"]}

    response = visits_client.post(
        BASE_URL,
        json={
            "city_id": LISBON_ID,
            "started_on": "2025-06-12",
            "ended_on": "2025-06-25",
            "new_country_visit": {
                "started_on": "2025-06-10",
                "ended_on": "2025-06-20",
            },
        },
        headers=ORIGIN,
    )

    assert response.status_code == 422
    assert "extend beyond" in response.json()["detail"]

    after_response = visits_client.get("/api/v1/country-visits")

    after_ids = {item["id"] for item in after_response.json()["items"]}

    assert after_ids == before_ids


def test_joint_creation_rolls_back_country_when_city_creation_fails(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    countries_before = visits_client.get("/api/v1/country-visits")

    assert countries_before.status_code == 200

    before_ids = {item["id"] for item in countries_before.json()["items"]}

    with (
        patch.object(
            CityVisitRepository,
            "create",
            side_effect=RuntimeError("Simulated city insert failure"),
        ),
        pytest.raises(
            RuntimeError,
            match="Simulated city insert failure",
        ),
    ):
        visits_client.post(
            BASE_URL,
            json={
                "city_id": LISBON_ID,
                "started_on": "2025-06-12",
                "ended_on": "2025-06-15",
                "new_country_visit": {
                    "started_on": "2025-06-10",
                    "ended_on": "2025-06-20",
                },
            },
            headers=ORIGIN,
        )

    countries_after = visits_client.get("/api/v1/country-visits")

    assert countries_after.status_code == 200

    after_ids = {item["id"] for item in countries_after.json()["items"]}

    assert after_ids == before_ids


def test_city_visit_create_accepts_expansion_confirmation() -> None:
    payload = CityVisitCreate.model_validate(
        {
            "city_id": LISBON_ID,
            "started_on": "2025-06-12",
            "ended_on": "2025-06-18",
            "country_visit_id": "11111111-1111-4111-8111-111111111111",
            "country_date_expansion": {
                "expected": {
                    "started_on": "2025-06-10",
                    "started_on_precision": "day",
                    "ended_on": "2025-06-15",
                    "ended_on_precision": "day",
                },
                "proposed": {
                    "started_on": "2025-06-10",
                    "started_on_precision": "day",
                    "ended_on": "2025-06-18",
                    "ended_on_precision": "day",
                },
            },
        }
    )

    assert payload.country_date_expansion is not None
    assert payload.country_date_expansion.proposed.ended_on == date(2025, 6, 18)


def test_city_visit_create_rejects_expansion_without_country_visit() -> None:
    with pytest.raises(ValueError, match="requires an existing country visit"):
        CityVisitCreate.model_validate(
            {
                "city_id": LISBON_ID,
                "started_on": "2025-06-12",
                "ended_on": "2025-06-18",
                "country_date_expansion": {
                    "expected": {
                        "started_on": "2025-06-10",
                        "started_on_precision": "day",
                        "ended_on": "2025-06-15",
                        "ended_on_precision": "day",
                    },
                    "proposed": {
                        "started_on": "2025-06-10",
                        "started_on_precision": "day",
                        "ended_on": "2025-06-18",
                        "ended_on_precision": "day",
                    },
                },
            }
        )


def test_city_visit_update_rejects_expansion_and_disassociation() -> None:
    with pytest.raises(ValueError, match="removing the association"):
        CityVisitUpdate.model_validate(
            {
                "country_visit_id": None,
                "country_date_expansion": {
                    "expected": {
                        "started_on": "2025-06-10",
                        "started_on_precision": "day",
                        "ended_on": "2025-06-15",
                        "ended_on_precision": "day",
                    },
                    "proposed": {
                        "started_on": "2025-06-10",
                        "started_on_precision": "day",
                        "ended_on": "2025-06-18",
                        "ended_on_precision": "day",
                    },
                },
            }
        )


def test_create_city_visit_returns_country_expansion_proposal(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    country_visit_id = create_country_visit(
        visits_client,
        started_on="2025-06-10",
        ended_on="2025-06-15",
    )

    response = visits_client.post(
        BASE_URL,
        json={
            "city_id": LISBON_ID,
            "started_on": "2025-06-12",
            "ended_on": "2025-06-18",
            "country_visit_id": country_visit_id,
        },
        headers=ORIGIN,
    )

    assert response.status_code == 409

    detail = response.json()["detail"]

    assert detail["code"] == "COUNTRY_VISIT_DATE_EXPANSION_REQUIRED"
    assert detail["country_visit_id"] == country_visit_id

    assert detail["current"] == {
        "started_on": "2025-06-10",
        "started_on_precision": "day",
        "ended_on": "2025-06-15",
        "ended_on_precision": "day",
    }

    assert detail["proposed"] == {
        "started_on": "2025-06-10",
        "started_on_precision": "day",
        "ended_on": "2025-06-18",
        "ended_on_precision": "day",
    }

    # The rejected operation must not create the city visit.
    cities = visits_client.get(BASE_URL)

    assert cities.status_code == 200

    assert not any(item["country_visit_id"] == country_visit_id for item in cities.json()["items"])


def test_patch_city_visit_returns_country_expansion_proposal(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    country_visit_id = create_country_visit(
        visits_client,
        started_on="2025-06-10",
        ended_on="2025-06-15",
    )

    city_visit_id = create_visit(
        visits_client,
        started_on="2025-06-12",
        ended_on="2025-06-18",
    )

    response = visits_client.patch(
        f"{BASE_URL}/{city_visit_id}",
        json={
            "country_visit_id": country_visit_id,
        },
        headers=ORIGIN,
    )

    assert response.status_code == 409

    detail = response.json()["detail"]

    assert detail["code"] == "COUNTRY_VISIT_DATE_EXPANSION_REQUIRED"
    assert detail["proposed"]["ended_on"] == "2025-06-18"

    cities = visits_client.get(BASE_URL)

    saved_city = next(item for item in cities.json()["items"] if item["id"] == city_visit_id)

    assert saved_city["country_visit_id"] is None

    countries = visits_client.get("/api/v1/country-visits")

    saved_country = next(
        item for item in countries.json()["items"] if item["id"] == country_visit_id
    )

    assert saved_country["ended_on"] == "2025-06-15"


def test_create_city_visit_applies_confirmed_country_expansion(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    country_visit_id = create_country_visit(
        visits_client,
        started_on="2025-06-10",
        ended_on="2025-06-15",
    )

    payload = {
        "city_id": LISBON_ID,
        "started_on": "2025-06-12",
        "ended_on": "2025-06-18",
        "country_visit_id": country_visit_id,
    }

    # First request: obtain the backend's proposed expansion.
    proposal_response = visits_client.post(
        BASE_URL,
        json=payload,
        headers=ORIGIN,
    )

    assert proposal_response.status_code == 409

    detail = proposal_response.json()["detail"]

    assert detail["code"] == "COUNTRY_VISIT_DATE_EXPANSION_REQUIRED"

    # Second request: explicitly confirm the exact proposal.
    response = visits_client.post(
        BASE_URL,
        json={
            **payload,
            "country_date_expansion": {
                "expected": detail["current"],
                "proposed": detail["proposed"],
            },
        },
        headers=ORIGIN,
    )

    assert response.status_code == 201

    city_visit = response.json()

    assert city_visit["country_visit_id"] == country_visit_id
    assert city_visit["ended_on"] == "2025-06-18"

    # Confirm that the country visit was actually expanded.
    countries = visits_client.get("/api/v1/country-visits")

    assert countries.status_code == 200

    saved_country = next(
        item for item in countries.json()["items"] if item["id"] == country_visit_id
    )

    assert saved_country["started_on"] == "2025-06-10"
    assert saved_country["ended_on"] == "2025-06-18"

    # Confirm that the city association was persisted.
    cities = visits_client.get(BASE_URL)

    assert cities.status_code == 200

    saved_city = next(item for item in cities.json()["items"] if item["id"] == city_visit["id"])

    assert saved_city["country_visit_id"] == country_visit_id


def test_create_city_visit_rejects_stale_expansion_confirmation(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    country_visit_id = create_country_visit(
        visits_client,
        started_on="2025-06-10",
        ended_on="2025-06-15",
    )

    payload = {
        "city_id": LISBON_ID,
        "started_on": "2025-06-12",
        "ended_on": "2025-06-18",
        "country_visit_id": country_visit_id,
    }

    proposal_response = visits_client.post(
        BASE_URL,
        json=payload,
        headers=ORIGIN,
    )

    assert proposal_response.status_code == 409

    detail = proposal_response.json()["detail"]

    # Simulate a change made after the user received the proposal.
    update_response = visits_client.patch(
        f"/api/v1/country-visits/{country_visit_id}",
        json={"ended_on": "2025-06-16"},
        headers=ORIGIN,
    )

    assert update_response.status_code == 200

    response = visits_client.post(
        BASE_URL,
        json={
            **payload,
            "country_date_expansion": {
                "expected": detail["current"],
                "proposed": detail["proposed"],
            },
        },
        headers=ORIGIN,
    )

    assert response.status_code == 409

    assert response.json()["detail"]["code"] == "COUNTRY_VISIT_DATE_EXPANSION_STALE"

    countries = visits_client.get("/api/v1/country-visits")

    saved_country = next(
        item for item in countries.json()["items"] if item["id"] == country_visit_id
    )

    # The stale confirmation must not overwrite the newer value.
    assert saved_country["ended_on"] == "2025-06-16"

    cities = visits_client.get(BASE_URL)

    assert not any(item["country_visit_id"] == country_visit_id for item in cities.json()["items"])


def test_create_city_visit_rejects_modified_expansion_confirmation(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    country_visit_id = create_country_visit(
        visits_client,
        started_on="2025-06-10",
        ended_on="2025-06-15",
    )

    payload = {
        "city_id": LISBON_ID,
        "started_on": "2025-06-12",
        "ended_on": "2025-06-18",
        "country_visit_id": country_visit_id,
    }

    proposal_response = visits_client.post(
        BASE_URL,
        json=payload,
        headers=ORIGIN,
    )

    assert proposal_response.status_code == 409

    detail = proposal_response.json()["detail"]

    modified_proposal = {
        **detail["proposed"],
        "ended_on": "2025-06-25",
    }

    response = visits_client.post(
        BASE_URL,
        json={
            **payload,
            "country_date_expansion": {
                "expected": detail["current"],
                "proposed": modified_proposal,
            },
        },
        headers=ORIGIN,
    )

    assert response.status_code == 409

    assert response.json()["detail"]["code"] == "COUNTRY_VISIT_DATE_EXPANSION_STALE"

    countries = visits_client.get("/api/v1/country-visits")

    saved_country = next(
        item for item in countries.json()["items"] if item["id"] == country_visit_id
    )

    assert saved_country["ended_on"] == "2025-06-15"


def test_patch_city_visit_applies_confirmed_country_expansion(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    country_visit_id = create_country_visit(
        visits_client,
        started_on="2025-06-10",
        ended_on="2025-06-15",
    )

    city_visit_id = create_visit(
        visits_client,
        started_on="2025-06-12",
        ended_on="2025-06-18",
    )

    url = f"{BASE_URL}/{city_visit_id}"

    # First request: obtain the expansion proposal.
    proposal_response = visits_client.patch(
        url,
        json={"country_visit_id": country_visit_id},
        headers=ORIGIN,
    )

    assert proposal_response.status_code == 409

    detail = proposal_response.json()["detail"]

    assert detail["code"] == "COUNTRY_VISIT_DATE_EXPANSION_REQUIRED"

    # Second request: confirm the exact proposal.
    response = visits_client.patch(
        url,
        json={
            "country_visit_id": country_visit_id,
            "country_date_expansion": {
                "expected": detail["current"],
                "proposed": detail["proposed"],
            },
        },
        headers=ORIGIN,
    )

    assert response.status_code == 200

    updated_city = response.json()

    assert updated_city["id"] == city_visit_id
    assert updated_city["country_visit_id"] == country_visit_id
    assert updated_city["started_on"] == "2025-06-12"
    assert updated_city["ended_on"] == "2025-06-18"

    # Verify the country date expansion was persisted.
    countries = visits_client.get("/api/v1/country-visits")

    assert countries.status_code == 200

    saved_country = next(
        item for item in countries.json()["items"] if item["id"] == country_visit_id
    )

    assert saved_country["started_on"] == "2025-06-10"
    assert saved_country["ended_on"] == "2025-06-18"

    # Verify the city association was persisted.
    cities = visits_client.get(BASE_URL)

    assert cities.status_code == 200

    saved_city = next(item for item in cities.json()["items"] if item["id"] == city_visit_id)

    assert saved_city["country_visit_id"] == country_visit_id


def test_patch_city_visit_rejects_stale_expansion_confirmation(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    country_visit_id = create_country_visit(
        visits_client,
        started_on="2025-06-10",
        ended_on="2025-06-15",
    )

    city_visit_id = create_visit(
        visits_client,
        started_on="2025-06-12",
        ended_on="2025-06-18",
    )

    url = f"{BASE_URL}/{city_visit_id}"

    proposal_response = visits_client.patch(
        url,
        json={"country_visit_id": country_visit_id},
        headers=ORIGIN,
    )

    assert proposal_response.status_code == 409

    detail = proposal_response.json()["detail"]

    # Another operation changes the country dates.
    country_update = visits_client.patch(
        f"/api/v1/country-visits/{country_visit_id}",
        json={"ended_on": "2025-06-16"},
        headers=ORIGIN,
    )

    assert country_update.status_code == 200

    # Attempt to confirm the previous proposal.
    response = visits_client.patch(
        url,
        json={
            "country_visit_id": country_visit_id,
            "country_date_expansion": {
                "expected": detail["current"],
                "proposed": detail["proposed"],
            },
        },
        headers=ORIGIN,
    )

    assert response.status_code == 409

    assert response.json()["detail"]["code"] == "COUNTRY_VISIT_DATE_EXPANSION_STALE"

    countries = visits_client.get("/api/v1/country-visits")

    assert countries.status_code == 200

    saved_country = next(
        item for item in countries.json()["items"] if item["id"] == country_visit_id
    )

    assert saved_country["ended_on"] == "2025-06-16"

    cities = visits_client.get(BASE_URL)

    assert cities.status_code == 200

    saved_city = next(item for item in cities.json()["items"] if item["id"] == city_visit_id)

    assert saved_city["country_visit_id"] is None
    assert saved_city["ended_on"] == "2025-06-18"


def test_patch_city_visit_rejects_modified_expansion_confirmation(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    country_visit_id = create_country_visit(
        visits_client,
        started_on="2025-06-10",
        ended_on="2025-06-15",
    )

    city_visit_id = create_visit(
        visits_client,
        started_on="2025-06-12",
        ended_on="2025-06-18",
    )

    url = f"{BASE_URL}/{city_visit_id}"

    proposal_response = visits_client.patch(
        url,
        json={"country_visit_id": country_visit_id},
        headers=ORIGIN,
    )

    assert proposal_response.status_code == 409

    detail = proposal_response.json()["detail"]

    modified_proposal = {
        **detail["proposed"],
        "ended_on": "2025-06-25",
    }

    response = visits_client.patch(
        url,
        json={
            "country_visit_id": country_visit_id,
            "country_date_expansion": {
                "expected": detail["current"],
                "proposed": modified_proposal,
            },
        },
        headers=ORIGIN,
    )

    assert response.status_code == 409

    assert response.json()["detail"]["code"] == "COUNTRY_VISIT_DATE_EXPANSION_STALE"

    countries = visits_client.get("/api/v1/country-visits")

    assert countries.status_code == 200

    saved_country = next(
        item for item in countries.json()["items"] if item["id"] == country_visit_id
    )

    assert saved_country["ended_on"] == "2025-06-15"

    cities = visits_client.get(BASE_URL)

    assert cities.status_code == 200

    saved_city = next(item for item in cities.json()["items"] if item["id"] == city_visit_id)

    assert saved_city["country_visit_id"] is None


def test_confirmed_expansion_rolls_back_when_city_creation_fails(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    country_visit_id = create_country_visit(
        visits_client,
        started_on="2025-06-10",
        ended_on="2025-06-15",
    )

    payload = {
        "city_id": LISBON_ID,
        "started_on": "2025-06-12",
        "ended_on": "2025-06-18",
        "country_visit_id": country_visit_id,
    }

    proposal_response = visits_client.post(
        BASE_URL,
        json=payload,
        headers=ORIGIN,
    )

    assert proposal_response.status_code == 409
    proposal = proposal_response.json()["detail"]

    with (
        patch.object(
            CityVisitRepository,
            "create",
            side_effect=RuntimeError("Simulated city insert failure"),
        ),
        pytest.raises(RuntimeError, match="Simulated city insert failure"),
    ):
        visits_client.post(
            BASE_URL,
            json={
                **payload,
                "country_date_expansion": {
                    "expected": proposal["current"],
                    "proposed": proposal["proposed"],
                },
            },
            headers=ORIGIN,
        )

    countries = visits_client.get("/api/v1/country-visits")
    assert countries.status_code == 200

    saved_country = next(
        item for item in countries.json()["items"] if item["id"] == country_visit_id
    )

    assert saved_country["ended_on"] == "2025-06-15"

    cities = visits_client.get(BASE_URL)
    assert cities.status_code == 200

    assert not any(item["country_visit_id"] == country_visit_id for item in cities.json()["items"])


def test_confirmed_expansion_rolls_back_when_city_update_fails(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    country_visit_id = create_country_visit(
        visits_client,
        started_on="2025-06-10",
        ended_on="2025-06-15",
    )

    city_visit_id = create_visit(
        visits_client,
        started_on="2025-06-12",
        ended_on="2025-06-18",
    )

    url = f"{BASE_URL}/{city_visit_id}"

    proposal_response = visits_client.patch(
        url,
        json={"country_visit_id": country_visit_id},
        headers=ORIGIN,
    )

    assert proposal_response.status_code == 409
    proposal = proposal_response.json()["detail"]

    with (
        patch.object(
            CityVisitRepository,
            "update",
            side_effect=RuntimeError("Simulated city update failure"),
        ),
        pytest.raises(RuntimeError, match="Simulated city update failure"),
    ):
        visits_client.patch(
            url,
            json={
                "country_visit_id": country_visit_id,
                "country_date_expansion": {
                    "expected": proposal["current"],
                    "proposed": proposal["proposed"],
                },
            },
            headers=ORIGIN,
        )

    countries = visits_client.get("/api/v1/country-visits")
    assert countries.status_code == 200

    saved_country = next(
        item for item in countries.json()["items"] if item["id"] == country_visit_id
    )

    assert saved_country["ended_on"] == "2025-06-15"

    cities = visits_client.get(BASE_URL)
    assert cities.status_code == 200

    saved_city = next(item for item in cities.json()["items"] if item["id"] == city_visit_id)

    assert saved_city["country_visit_id"] is None
    assert saved_city["ended_on"] == "2025-06-18"
