"""Integration tests for Trip REST endpoints."""

from collections.abc import Generator
from pathlib import Path
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import Engine, select
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.security import hash_password
from app.db.base import Base
from app.db.session import create_database_engine, get_db
from app.main import create_app
from app.models.trip import Trip
from app.models.user import User


TEST_PASSWORD = "correct-password-123"

BASE_URL = "/api/v1/trips"

ORIGIN = {
    "Origin": "http://testserver",
}


@pytest.fixture
def trips_client(
    tmp_path: Path,
) -> Generator[tuple[TestClient, Engine], None, None]:
    """Create an isolated Trip API test environment."""

    engine = create_database_engine(
        f"sqlite:///{tmp_path / 'trips_api.db'}"
    )

    Base.metadata.create_all(engine)

    with Session(engine) as session:
        session.add_all(
            [
                User(
                    username="goncalo",
                    email="goncalo@example.com",
                    display_name="Gonçalo",
                    password_hash=hash_password(TEST_PASSWORD),
                ),
                User(
                    username="anotheruser",
                    email="another@example.com",
                    display_name="Another User",
                    password_hash=hash_password(TEST_PASSWORD),
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
        yield client, engine

    app.dependency_overrides.clear()
    engine.dispose()


def login_web(
    client: TestClient,
    username: str = "goncalo",
) -> None:
    """Authenticate using the Web login."""

    response = client.post(
        "/api/v1/auth/login",
        json={
            "login": username,
            "password": TEST_PASSWORD,
        },
        headers=ORIGIN,
    )

    assert response.status_code == 200, response.text


def login_mobile(
    client: TestClient,
) -> dict[str, str]:
    """Authenticate using a Mobile Bearer token."""

    response = client.post(
        "/api/v1/auth/mobile/login",
        json={
            "login": "goncalo",
            "password": TEST_PASSWORD,
        },
    )

    assert response.status_code == 200, response.text

    return {
        "Authorization": f"Bearer {response.json()['access_token']}",
    }


def create_trip(
    client: TestClient,
    payload: dict | None = None,
    *,
    headers: dict[str, str] | None = None,
) -> dict:
    """Create a Trip and return its API representation."""

    response = client.post(
        BASE_URL,
        json=payload or {"name": "Japan 2027"},
        headers=ORIGIN | (headers or {}),
    )

    assert response.status_code == 201, response.text

    return response.json()


def count_trips(engine: Engine) -> int:
    """Count persisted Trips."""

    with Session(engine) as session:
        return len(session.scalars(select(Trip)).all())


# ---------------------------------------------------------
# Authentication
# ---------------------------------------------------------


@pytest.mark.parametrize(
    "method,path",
    [
        ("GET", BASE_URL),
        ("GET", f"{BASE_URL}/{uuid4()}"),
        ("POST", BASE_URL),
        ("PATCH", f"{BASE_URL}/{uuid4()}"),
        ("DELETE", f"{BASE_URL}/{uuid4()}"),
    ],
)
def test_anonymous_requests_are_rejected(
    trips_client: tuple[TestClient, Engine],
    method: str,
    path: str,
) -> None:
    client, _ = trips_client

    response = client.request(
        method,
        path,
        json={"name": "Japan"} if method in {"POST", "PATCH"} else None,
        headers=ORIGIN,
    )

    assert response.status_code == 401


def test_mobile_authentication_supports_crud(
    trips_client: tuple[TestClient, Engine],
) -> None:
    client, _ = trips_client

    headers = login_mobile(client)

    trip = create_trip(
        client,
        headers=headers,
    )

    trip_id = trip["id"]

    listed = client.get(BASE_URL, headers=headers)

    assert listed.status_code == 200
    assert listed.json()["total"] == 1

    retrieved = client.get(
        f"{BASE_URL}/{trip_id}",
        headers=headers,
    )

    assert retrieved.status_code == 200

    updated = client.patch(
        f"{BASE_URL}/{trip_id}",
        json={"name": "Updated Japan"},
        headers=ORIGIN | headers,
    )

    assert updated.status_code == 200
    assert updated.json()["name"] == "Updated Japan"

    deleted = client.delete(
        f"{BASE_URL}/{trip_id}",
        headers=ORIGIN | headers,
    )

    assert deleted.status_code == 204


# ---------------------------------------------------------
# GET
# ---------------------------------------------------------


def test_empty_trips_list(
    trips_client: tuple[TestClient, Engine],
) -> None:
    client, _ = trips_client

    login_web(client)

    response = client.get(BASE_URL)

    assert response.status_code == 200

    assert response.json() == {
        "items": [],
        "total": 0,
    }


def test_list_trips(
    trips_client: tuple[TestClient, Engine],
) -> None:
    client, _ = trips_client

    login_web(client)

    create_trip(client, {"name": "Japan 2027"})
    create_trip(client, {"name": "Italy 2026"})

    response = client.get(BASE_URL)

    assert response.status_code == 200

    data = response.json()

    assert data["total"] == 2

    assert {trip["name"] for trip in data["items"]} == {
        "Japan 2027",
        "Italy 2026",
    }


def test_get_owned_trip(
    trips_client: tuple[TestClient, Engine],
) -> None:
    client, _ = trips_client

    login_web(client)

    trip = create_trip(client)

    response = client.get(
        f"{BASE_URL}/{trip['id']}"
    )

    assert response.status_code == 200

    data = response.json()

    assert data["id"] == trip["id"]
    assert data["name"] == "Japan 2027"
    assert data["created_at"] is not None
    assert data["updated_at"] is not None


def test_get_missing_trip(
    trips_client: tuple[TestClient, Engine],
) -> None:
    client, _ = trips_client

    login_web(client)

    response = client.get(
        f"{BASE_URL}/{uuid4()}"
    )

    assert response.status_code == 404


def test_get_invalid_uuid(
    trips_client: tuple[TestClient, Engine],
) -> None:
    client, _ = trips_client

    login_web(client)

    response = client.get(
        f"{BASE_URL}/invalid-uuid"
    )

    assert response.status_code == 422


# ---------------------------------------------------------
# POST
# ---------------------------------------------------------


def test_create_trip_without_dates(
    trips_client: tuple[TestClient, Engine],
) -> None:
    client, engine = trips_client

    login_web(client)

    trip = create_trip(client)

    assert trip["name"] == "Japan 2027"
    assert trip["description"] is None

    assert trip["started_on"] is None
    assert trip["ended_on"] is None

    assert trip["id"] is not None
    assert trip["created_at"] is not None
    assert trip["updated_at"] is not None

    assert count_trips(engine) == 1


def test_create_trip_with_dates(
    trips_client: tuple[TestClient, Engine],
) -> None:
    client, _ = trips_client

    login_web(client)

    trip = create_trip(
        client,
        {
            "name": "Japan 2027",
            "description": "Spring holiday",
            "started_on": "2027-04-10",
            "ended_on": "2027-04-25",
        },
    )

    assert trip["description"] == "Spring holiday"
    assert trip["started_on"] == "2027-04-10"
    assert trip["started_on_precision"] == "day"
    assert trip["ended_on"] == "2027-04-25"
    assert trip["ended_on_precision"] == "day"


def test_create_trip_with_partial_dates(
    trips_client: tuple[TestClient, Engine],
) -> None:
    client, _ = trips_client

    login_web(client)

    trip = create_trip(
        client,
        {
            "name": "Japan",
            "started_on": "2027-04-15",
            "started_on_precision": "month",
            "ended_on": "2028-07-20",
            "ended_on_precision": "year",
        },
    )

    assert trip["started_on"] == "2027-04-01"
    assert trip["started_on_precision"] == "month"

    assert trip["ended_on"] == "2028-01-01"
    assert trip["ended_on_precision"] == "year"


def test_duplicate_trip_names_are_allowed(
    trips_client: tuple[TestClient, Engine],
) -> None:
    client, engine = trips_client

    login_web(client)

    first = create_trip(client)
    second = create_trip(client)

    assert first["id"] != second["id"]
    assert first["name"] == second["name"]

    assert count_trips(engine) == 2


@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"name": ""},
        {"name": "   "},
        {"name": "A" * 161},
        {"name": "Japan", "description": "A" * 5001},
        {"name": "Japan", "unknown_field": True},
        {"name": "Japan", "started_on_precision": "day"},
        {
            "name": "Japan",
            "started_on": "2027-05-10",
            "ended_on": "2027-04-10",
        },
    ],
)
def test_create_rejects_invalid_payload(
    trips_client: tuple[TestClient, Engine],
    payload: dict,
) -> None:
    client, engine = trips_client

    login_web(client)

    response = client.post(
        BASE_URL,
        json=payload,
        headers=ORIGIN,
    )

    assert response.status_code == 422
    assert count_trips(engine) == 0


# ---------------------------------------------------------
# PATCH
# ---------------------------------------------------------


def test_update_name(
    trips_client: tuple[TestClient, Engine],
) -> None:
    client, _ = trips_client

    login_web(client)

    trip = create_trip(client)

    response = client.patch(
        f"{BASE_URL}/{trip['id']}",
        json={"name": "Japan & Korea 2027"},
        headers=ORIGIN,
    )

    assert response.status_code == 200
    assert response.json()["name"] == "Japan & Korea 2027"


def test_update_description(
    trips_client: tuple[TestClient, Engine],
) -> None:
    client, _ = trips_client

    login_web(client)

    trip = create_trip(client)

    response = client.patch(
        f"{BASE_URL}/{trip['id']}",
        json={"description": "My first trip to Japan"},
        headers=ORIGIN,
    )

    assert response.status_code == 200

    assert response.json()["description"] == "My first trip to Japan"


def test_remove_description(
    trips_client: tuple[TestClient, Engine],
) -> None:
    client, _ = trips_client

    login_web(client)

    trip = create_trip(
        client,
        {
            "name": "Japan",
            "description": "Original description",
        },
    )

    response = client.patch(
        f"{BASE_URL}/{trip['id']}",
        json={"description": None},
        headers=ORIGIN,
    )

    assert response.status_code == 200
    assert response.json()["description"] is None


def test_remove_start_date(
    trips_client: tuple[TestClient, Engine],
) -> None:
    client, _ = trips_client

    login_web(client)

    trip = create_trip(
        client,
        {
            "name": "Japan",
            "started_on": "2027-04-10",
            "ended_on": "2027-04-25",
        },
    )

    response = client.patch(
        f"{BASE_URL}/{trip['id']}",
        json={"started_on": None},
        headers=ORIGIN,
    )

    assert response.status_code == 200

    data = response.json()

    assert data["started_on"] is None
    assert data["started_on_precision"] is None

    assert data["ended_on"] == "2027-04-25"


def test_reduce_date_precision(
    trips_client: tuple[TestClient, Engine],
) -> None:
    client, _ = trips_client

    login_web(client)

    trip = create_trip(
        client,
        {
            "name": "Japan",
            "started_on": "2027-04-10",
        },
    )

    response = client.patch(
        f"{BASE_URL}/{trip['id']}",
        json={"started_on_precision": "year"},
        headers=ORIGIN,
    )

    assert response.status_code == 200

    data = response.json()

    assert data["started_on"] == "2027-01-01"
    assert data["started_on_precision"] == "year"


def test_reject_increasing_precision_without_new_date(
    trips_client: tuple[TestClient, Engine],
) -> None:
    client, _ = trips_client

    login_web(client)

    trip = create_trip(
        client,
        {
            "name": "Japan",
            "started_on": "2027-04-10",
            "started_on_precision": "year",
        },
    )

    response = client.patch(
        f"{BASE_URL}/{trip['id']}",
        json={"started_on_precision": "day"},
        headers=ORIGIN,
    )

    assert response.status_code == 422


def test_reject_invalid_date_update_without_mutation(
    trips_client: tuple[TestClient, Engine],
) -> None:
    client, engine = trips_client

    login_web(client)

    trip = create_trip(
        client,
        {
            "name": "Japan",
            "started_on": "2027-04-10",
            "ended_on": "2027-04-25",
        },
    )

    response = client.patch(
        f"{BASE_URL}/{trip['id']}",
        json={
            "name": "Should Not Persist",
            "ended_on": "2027-03-01",
        },
        headers=ORIGIN,
    )

    assert response.status_code == 422

    with Session(engine) as session:
        saved = session.get(Trip, UUID(trip["id"]))

        assert saved is not None
        assert saved.name == "Japan"
        assert saved.ended_on.isoformat() == "2027-04-25"


@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"name": None},
        {"name": ""},
        {"name": "   "},
        {"unknown_field": "value"},
        {"started_on_precision": None},
    ],
)
def test_patch_rejects_invalid_payload(
    trips_client: tuple[TestClient, Engine],
    payload: dict,
) -> None:
    client, _ = trips_client

    login_web(client)

    trip = create_trip(
        client,
        {
            "name": "Japan",
            "started_on": "2027-04-10",
        },
    )

    response = client.patch(
        f"{BASE_URL}/{trip['id']}",
        json=payload,
        headers=ORIGIN,
    )

    assert response.status_code == 422


# ---------------------------------------------------------
# Multi-user isolation
# ---------------------------------------------------------


def test_users_have_independent_trips(
    trips_client: tuple[TestClient, Engine],
) -> None:
    client, engine = trips_client

    login_web(client, "goncalo")

    first = create_trip(client)

    login_web(client, "anotheruser")

    listed = client.get(BASE_URL)

    assert listed.status_code == 200
    assert listed.json()["total"] == 0

    retrieved = client.get(
        f"{BASE_URL}/{first['id']}"
    )

    assert retrieved.status_code == 404

    updated = client.patch(
        f"{BASE_URL}/{first['id']}",
        json={"name": "Unauthorized"},
        headers=ORIGIN,
    )

    assert updated.status_code == 404

    deleted = client.delete(
        f"{BASE_URL}/{first['id']}",
        headers=ORIGIN,
    )

    assert deleted.status_code == 404

    second = create_trip(
        client,
        {"name": "Italy"},
    )

    assert second["id"] != first["id"]

    assert count_trips(engine) == 2

    login_web(client, "goncalo")

    original = client.get(BASE_URL)

    assert original.status_code == 200
    assert original.json()["total"] == 1
    assert original.json()["items"][0]["id"] == first["id"]


# ---------------------------------------------------------
# DELETE
# ---------------------------------------------------------


def test_delete_owned_trip(
    trips_client: tuple[TestClient, Engine],
) -> None:
    client, engine = trips_client

    login_web(client)

    trip = create_trip(client)

    response = client.delete(
        f"{BASE_URL}/{trip['id']}",
        headers=ORIGIN,
    )

    assert response.status_code == 204
    assert not response.content

    assert count_trips(engine) == 0

    missing = client.get(
        f"{BASE_URL}/{trip['id']}"
    )

    assert missing.status_code == 404


def test_delete_missing_trip(
    trips_client: tuple[TestClient, Engine],
) -> None:
    client, _ = trips_client

    login_web(client)

    response = client.delete(
        f"{BASE_URL}/{uuid4()}",
        headers=ORIGIN,
    )

    assert response.status_code == 404