"""Tests for authenticated country visit listing."""

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
from app.models.country import Country
from app.models.country_visit import CountryVisit
from app.models.user import User

TEST_PASSWORD = "correct-password-123"


@pytest.fixture
def visits_client(
    tmp_path: Path,
) -> Generator[TestClient, None, None]:
    engine = create_database_engine(f"sqlite:///{tmp_path / 'country_visits_api.db'}")

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
                CountryVisit(
                    user_id=first_user.id,
                    country_code="PT",
                    started_on=date(2025, 7, 10),
                    started_on_precision="day",
                    ended_on=date(2025, 7, 15),
                    ended_on_precision="day",
                ),
                CountryVisit(
                    user_id=first_user.id,
                    country_code="PT",
                    started_on=date(2026, 2, 1),
                    started_on_precision="day",
                    ended_on=date(2026, 2, 5),
                    ended_on_precision="day",
                ),
                CountryVisit(
                    user_id=first_user.id,
                    country_code="ES",
                ),
                CountryVisit(
                    user_id=second_user.id,
                    country_code="ES",
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


def login_web(
    client: TestClient,
    username: str = "goncalo",
) -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={
            "login": username,
            "password": TEST_PASSWORD,
        },
    )

    assert response.status_code == 200


def login_mobile(
    client: TestClient,
    username: str = "goncalo",
) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/mobile/login",
        json={
            "login": username,
            "password": TEST_PASSWORD,
        },
    )

    assert response.status_code == 200

    return {
        "Authorization": f"Bearer {response.json()['access_token']}",
    }


def create_visit_for_test(
    client: TestClient,
    *,
    country_code: str = "PT",
    started_on: str | None = None,
    ended_on: str | None = None,
) -> str:
    payload = {
        "country_code": country_code,
        "started_on": started_on,
        "ended_on": ended_on,
    }

    response = client.post(
        "/api/v1/country-visits",
        json=payload,
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 201

    return response.json()["id"]


def test_listing_requires_authentication(
    visits_client: TestClient,
) -> None:
    response = visits_client.get("/api/v1/country-visits")

    assert response.status_code == 401


def test_web_user_can_list_own_visits(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.get("/api/v1/country-visits")

    assert response.status_code == 200

    body = response.json()

    assert body["total"] == 3
    assert len(body["items"]) == 3

    assert sorted(visit["country_code"] for visit in body["items"]) == ["ES", "PT", "PT"]

    assert all("user_id" not in visit for visit in body["items"])


def test_mobile_user_can_list_own_visits(
    visits_client: TestClient,
) -> None:
    headers = login_mobile(visits_client)

    response = visits_client.get(
        "/api/v1/country-visits",
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["total"] == 3


def test_user_cannot_list_another_users_visits(
    visits_client: TestClient,
) -> None:
    login_web(visits_client, username="anotheruser")

    response = visits_client.get("/api/v1/country-visits")

    assert response.status_code == 200

    body = response.json()

    assert body["total"] == 1
    assert body["items"][0]["country_code"] == "ES"
    assert body["items"][0]["started_on"] == "2024-08-01"


def test_multiple_visits_to_same_country_are_preserved(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.get("/api/v1/country-visits")

    assert response.status_code == 200

    portugal_visits = [visit for visit in response.json()["items"] if visit["country_code"] == "PT"]

    assert len(portugal_visits) == 2

    assert {visit["started_on"] for visit in portugal_visits} == {
        "2025-07-10",
        "2026-02-01",
    }


def test_visits_without_dates_are_supported(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.get("/api/v1/country-visits")

    assert response.status_code == 200

    undated_visits = [visit for visit in response.json()["items"] if visit["started_on"] is None]

    assert len(undated_visits) == 1
    assert undated_visits[0]["ended_on"] is None


def test_invalid_bearer_does_not_fallback_to_cookie(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.get(
        "/api/v1/country-visits",
        headers={
            "Authorization": "Bearer invalid-token",
        },
    )

    assert response.status_code == 401


def test_response_contains_expected_fields(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.get("/api/v1/country-visits")

    assert response.status_code == 200

    visit = response.json()["items"][0]

    assert set(visit) == {
        "id",
        "country_code",
        "started_on",
        "ended_on",
        "created_at",
        "updated_at",
        "started_on_precision",
        "ended_on_precision",
    }


def test_create_country_visit(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        "/api/v1/country-visits",
        json={
            "country_code": "PT",
            "started_on": "2025-07-10",
            "ended_on": "2025-07-15",
        },
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 201

    body = response.json()

    assert body["country_code"] == "PT"
    assert body["started_on"] == "2025-07-10"
    assert body["ended_on"] == "2025-07-15"
    assert body["id"] is not None
    assert "user_id" not in body


def test_create_country_visit_normalizes_country_code(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        "/api/v1/country-visits",
        json={"country_code": " pt "},
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 201
    assert response.json()["country_code"] == "PT"


def test_create_country_visit_without_dates(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        "/api/v1/country-visits",
        json={"country_code": "ES"},
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 201
    assert response.json()["started_on"] is None
    assert response.json()["ended_on"] is None


def test_create_country_visit_rejects_unknown_country(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        "/api/v1/country-visits",
        json={"country_code": "ZZ"},
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 404


def test_create_country_visit_rejects_end_without_start(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        "/api/v1/country-visits",
        json={
            "country_code": "PT",
            "ended_on": "2025-07-15",
        },
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 422


def test_create_country_visit_rejects_invalid_date_range(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        "/api/v1/country-visits",
        json={
            "country_code": "PT",
            "started_on": "2025-07-15",
            "ended_on": "2025-07-10",
        },
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 422


def test_create_country_visit_rejects_user_id(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        "/api/v1/country-visits",
        json={
            "country_code": "PT",
            "user_id": "550e8400-e29b-41d4-a716-446655440000",
        },
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 422


def test_create_country_visit_requires_authentication(
    visits_client: TestClient,
) -> None:
    response = visits_client.post(
        "/api/v1/country-visits",
        json={"country_code": "PT"},
    )

    assert response.status_code == 401


def test_mobile_user_can_create_country_visit(
    visits_client: TestClient,
) -> None:
    headers = login_mobile(visits_client)

    response = visits_client.post(
        "/api/v1/country-visits",
        json={"country_code": "PT"},
        headers=headers,
    )

    assert response.status_code == 201
    assert response.json()["country_code"] == "PT"


def test_create_country_visit_rejects_external_origin(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        "/api/v1/country-visits",
        json={"country_code": "PT"},
        headers={"Origin": "https://evil.example"},
    )

    assert response.status_code == 403


def test_update_country_visit(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    visit_id = create_visit_for_test(visits_client)

    response = visits_client.patch(
        f"/api/v1/country-visits/{visit_id}",
        json={
            "country_code": "ES",
            "started_on": "2026-09-28",
            "ended_on": "2026-10-03",
        },
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 200

    body = response.json()

    assert body["id"] == visit_id
    assert body["country_code"] == "ES"
    assert body["started_on"] == "2026-09-28"
    assert body["ended_on"] == "2026-10-03"


def test_update_preserves_omitted_fields(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    visit_id = create_visit_for_test(
        visits_client,
        started_on="2026-09-28",
        ended_on="2026-10-03",
    )

    response = visits_client.patch(
        f"/api/v1/country-visits/{visit_id}",
        json={"country_code": "ES"},
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 200

    body = response.json()

    assert body["country_code"] == "ES"
    assert body["started_on"] == "2026-09-28"
    assert body["ended_on"] == "2026-10-03"


def test_update_can_clear_end_date(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    visit_id = create_visit_for_test(
        visits_client,
        started_on="2026-09-28",
        ended_on="2026-10-03",
    )

    response = visits_client.patch(
        f"/api/v1/country-visits/{visit_id}",
        json={"ended_on": None},
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 200
    assert response.json()["started_on"] == "2026-09-28"
    assert response.json()["ended_on"] is None


def test_update_rejects_invalid_final_date_range(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    visit_id = create_visit_for_test(
        visits_client,
        started_on="2026-09-28",
        ended_on="2026-10-03",
    )

    response = visits_client.patch(
        f"/api/v1/country-visits/{visit_id}",
        json={"started_on": "2026-10-05"},
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 422

    # The rejected update must not modify the persisted visit.
    listing = visits_client.get("/api/v1/country-visits")

    visit = next(item for item in listing.json()["items"] if item["id"] == visit_id)

    assert visit["started_on"] == "2026-09-28"
    assert visit["ended_on"] == "2026-10-03"


def test_update_rejects_empty_payload(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    visit_id = create_visit_for_test(visits_client)

    response = visits_client.patch(
        f"/api/v1/country-visits/{visit_id}",
        json={},
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 422


def test_update_rejects_user_id(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    visit_id = create_visit_for_test(visits_client)

    response = visits_client.patch(
        f"/api/v1/country-visits/{visit_id}",
        json={
            "user_id": "550e8400-e29b-41d4-a716-446655440000",
        },
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 422


def test_update_rejects_unknown_country(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    visit_id = create_visit_for_test(visits_client)

    response = visits_client.patch(
        f"/api/v1/country-visits/{visit_id}",
        json={"country_code": "ZZ"},
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 404


def test_delete_country_visit(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    visit_id = create_visit_for_test(visits_client)

    response = visits_client.delete(
        f"/api/v1/country-visits/{visit_id}",
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 204
    assert response.content == b""

    listing = visits_client.get("/api/v1/country-visits")

    assert all(item["id"] != visit_id for item in listing.json()["items"])


def test_delete_country_visit_twice_returns_404(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    visit_id = create_visit_for_test(visits_client)

    first = visits_client.delete(
        f"/api/v1/country-visits/{visit_id}",
        headers={"Origin": "http://testserver"},
    )

    second = visits_client.delete(
        f"/api/v1/country-visits/{visit_id}",
        headers={"Origin": "http://testserver"},
    )

    assert first.status_code == 204
    assert second.status_code == 404


def test_cannot_update_another_users_visit(
    visits_client: TestClient,
) -> None:
    login_web(visits_client, username="anotheruser")

    listing = visits_client.get("/api/v1/country-visits")

    assert listing.status_code == 200
    assert listing.json()["total"] == 1

    other_visit_id = listing.json()["items"][0]["id"]

    # Switch to the first user.
    visits_client.cookies.clear()
    login_web(visits_client, username="goncalo")

    response = visits_client.patch(
        f"/api/v1/country-visits/{other_visit_id}",
        json={"country_code": "PT"},
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 404


def test_cannot_delete_another_users_visit(
    visits_client: TestClient,
) -> None:
    login_web(visits_client, username="anotheruser")

    listing = visits_client.get("/api/v1/country-visits")

    other_visit_id = listing.json()["items"][0]["id"]

    visits_client.cookies.clear()
    login_web(visits_client, username="goncalo")

    response = visits_client.delete(
        f"/api/v1/country-visits/{other_visit_id}",
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 404

    # Confirm the original owner's visit was not deleted.
    visits_client.cookies.clear()
    login_web(visits_client, username="anotheruser")

    listing = visits_client.get("/api/v1/country-visits")

    assert any(item["id"] == other_visit_id for item in listing.json()["items"])


def test_update_requires_authentication(
    visits_client: TestClient,
) -> None:
    response = visits_client.patch(
        "/api/v1/country-visits/550e8400-e29b-41d4-a716-446655440000",
        json={"country_code": "PT"},
    )

    assert response.status_code == 401


def test_delete_requires_authentication(
    visits_client: TestClient,
) -> None:
    response = visits_client.delete(
        "/api/v1/country-visits/550e8400-e29b-41d4-a716-446655440000",
    )

    assert response.status_code == 401


def test_update_rejects_external_origin(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    visit_id = create_visit_for_test(visits_client)

    response = visits_client.patch(
        f"/api/v1/country-visits/{visit_id}",
        json={"country_code": "ES"},
        headers={"Origin": "https://evil.example"},
    )

    assert response.status_code == 403


def test_delete_rejects_external_origin(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    visit_id = create_visit_for_test(visits_client)

    response = visits_client.delete(
        f"/api/v1/country-visits/{visit_id}",
        headers={"Origin": "https://evil.example"},
    )

    assert response.status_code == 403


def test_mobile_user_can_update_country_visit(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)
    visit_id = create_visit_for_test(visits_client)

    visits_client.cookies.clear()
    headers = login_mobile(visits_client)

    response = visits_client.patch(
        f"/api/v1/country-visits/{visit_id}",
        json={"country_code": "ES"},
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["country_code"] == "ES"


def test_mobile_user_can_delete_country_visit(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)
    visit_id = create_visit_for_test(visits_client)

    visits_client.cookies.clear()
    headers = login_mobile(visits_client)

    response = visits_client.delete(
        f"/api/v1/country-visits/{visit_id}",
        headers=headers,
    )

    assert response.status_code == 204


def test_update_nonexistent_visit_returns_404(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.patch(
        "/api/v1/country-visits/550e8400-e29b-41d4-a716-446655440000",
        json={"country_code": "PT"},
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 404


def test_delete_nonexistent_visit_returns_404(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.delete(
        "/api/v1/country-visits/550e8400-e29b-41d4-a716-446655440000",
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 404


def test_update_cannot_clear_start_with_existing_end(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    visit_id = create_visit_for_test(
        visits_client,
        started_on="2026-09-28",
        ended_on="2026-10-03",
    )

    response = visits_client.patch(
        f"/api/v1/country-visits/{visit_id}",
        json={"started_on": None},
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 422


def test_update_rejects_null_country_code(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)
    visit_id = create_visit_for_test(visits_client)

    response = visits_client.patch(
        f"/api/v1/country-visits/{visit_id}",
        json={"country_code": None},
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 422


def test_update_invalid_bearer_does_not_fallback_to_cookie(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)
    visit_id = create_visit_for_test(visits_client)

    response = visits_client.patch(
        f"/api/v1/country-visits/{visit_id}",
        json={"country_code": "ES"},
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
def test_create_country_visit_with_partial_start_date(
    visits_client: TestClient,
    precision: str,
    input_date: str,
    expected_date: str,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        "/api/v1/country-visits",
        json={
            "country_code": "PT",
            "started_on": input_date,
            "started_on_precision": precision,
        },
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 201

    body = response.json()

    assert body["started_on"] == expected_date
    assert body["started_on_precision"] == precision
    assert body["ended_on"] is None
    assert body["ended_on_precision"] is None

    listing = visits_client.get("/api/v1/country-visits")

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
def test_update_country_visit_precision_only(
    visits_client: TestClient,
    precision: str,
    expected_date: str,
) -> None:
    login_web(visits_client)

    visit_id = create_visit_for_test(
        visits_client,
        started_on="2026-09-28",
    )

    response = visits_client.patch(
        f"/api/v1/country-visits/{visit_id}",
        json={"started_on_precision": precision},
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 200
    assert response.json()["started_on"] == expected_date
    assert response.json()["started_on_precision"] == precision


def test_update_country_visit_date_without_precision_defaults_to_day(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        "/api/v1/country-visits",
        json={
            "country_code": "PT",
            "started_on": "2026-09-28",
            "started_on_precision": "month",
        },
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 201

    visit_id = response.json()["id"]

    response = visits_client.patch(
        f"/api/v1/country-visits/{visit_id}",
        json={"started_on": "2026-10-15"},
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 200
    assert response.json()["started_on"] == "2026-10-15"
    assert response.json()["started_on_precision"] == "day"


def test_update_country_visit_clears_date_and_precision(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    visit_id = create_visit_for_test(
        visits_client,
        started_on="2026-09-28",
    )

    response = visits_client.patch(
        f"/api/v1/country-visits/{visit_id}",
        json={"started_on": None},
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 200
    assert response.json()["started_on"] is None
    assert response.json()["started_on_precision"] is None


def test_update_country_visit_rejects_precision_increase_without_date(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        "/api/v1/country-visits",
        json={
            "country_code": "PT",
            "started_on": "2026-09-28",
            "started_on_precision": "year",
        },
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 201

    visit_id = response.json()["id"]

    response = visits_client.patch(
        f"/api/v1/country-visits/{visit_id}",
        json={"started_on_precision": "month"},
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 422


@pytest.mark.parametrize(
    "payload",
    [
        {
            "country_code": "PT",
            "started_on_precision": "month",
        },
        {
            "country_code": "PT",
            "started_on": "2026-09-28",
            "started_on_precision": "invalid",
        },
        {
            "country_code": "PT",
            "started_on": "2026-09-28",
            "started_on_precision": None,
        },
    ],
)
def test_create_country_visit_rejects_invalid_precision(
    visits_client: TestClient,
    payload: dict,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        "/api/v1/country-visits",
        json=payload,
        headers={"Origin": "http://testserver"},
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
def test_create_country_visit_with_partial_end_date(
    visits_client: TestClient,
    started_on: str,
    started_precision: str,
    ended_on: str,
    ended_precision: str,
    expected_end: str,
) -> None:
    login_web(visits_client)

    response = visits_client.post(
        "/api/v1/country-visits",
        json={
            "country_code": "PT",
            "started_on": started_on,
            "started_on_precision": started_precision,
            "ended_on": ended_on,
            "ended_on_precision": ended_precision,
        },
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 201

    body = response.json()
    assert body["ended_on"] == expected_end
    assert body["ended_on_precision"] == ended_precision


def test_country_visit_patch_precision_persists(
    visits_client: TestClient,
) -> None:
    login_web(visits_client)

    visit_id = create_visit_for_test(
        visits_client,
        started_on="2026-09-28",
    )

    response = visits_client.patch(
        f"/api/v1/country-visits/{visit_id}",
        json={"started_on_precision": "month"},
        headers={"Origin": "http://testserver"},
    )

    assert response.status_code == 200

    listing = visits_client.get("/api/v1/country-visits")
    assert listing.status_code == 200

    saved = next(
        item for item in listing.json()["items"] if item["id"] == visit_id
    )

    assert saved["started_on"] == "2026-09-01"
    assert saved["started_on_precision"] == "month"