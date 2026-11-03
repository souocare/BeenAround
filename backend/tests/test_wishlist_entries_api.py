"""Integration tests for global wishlist REST endpoints."""

from collections.abc import Generator
from pathlib import Path
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import Engine, select
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.security import hash_password
from app.db.base import Base
from app.db.session import create_database_engine, get_db
from app.main import create_app
from app.models.city import City
from app.models.city_visit import CityVisit
from app.models.country import Country
from app.models.country_visit import CountryVisit
from app.models.residence import Residence
from app.models.user import User
from app.models.wishlist_entry import WishlistEntry


TEST_PASSWORD = "correct-password-123"

LISBON_ID = 2267057
MADRID_ID = 3117735

BASE_URL = "/api/v1/wishlist"
ORIGIN = {"Origin": "http://testserver"}


@pytest.fixture
def wishlist_client(
    tmp_path: Path,
) -> Generator[tuple[TestClient, Engine], None, None]:
    """Create an isolated API client backed by SQLite."""

    engine = create_database_engine(f"sqlite:///{tmp_path / 'wishlist_api.db'}")

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
    """Authenticate through the Web cookie-based login."""

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
    username: str = "goncalo",
) -> dict[str, str]:
    """Authenticate through the Mobile Bearer flow."""

    response = client.post(
        "/api/v1/auth/mobile/login",
        json={
            "login": username,
            "password": TEST_PASSWORD,
        },
    )

    assert response.status_code == 200, response.text

    return {
        "Authorization": f"Bearer {response.json()['access_token']}",
    }


def post_wishlist(
    client: TestClient,
    payload: dict,
    *,
    headers: dict[str, str] | None = None,
):
    """Send a wishlist creation request."""

    return client.post(
        BASE_URL,
        json=payload,
        headers=ORIGIN | (headers or {}),
    )


def create_country(
    client: TestClient,
    code: str = "PT",
    *,
    headers: dict[str, str] | None = None,
) -> str:
    """Create a country entry and return its identifier."""

    response = post_wishlist(
        client,
        {"country_code": code},
        headers=headers,
    )

    assert response.status_code == 201, response.text

    data = response.json()

    assert len(data["created"]) == 1

    return data["created"][0]["id"]


def count_wishlist_entries(
    engine: Engine,
) -> int:
    """Count persisted wishlist entries."""

    with Session(engine) as session:
        return len(session.scalars(select(WishlistEntry)).all())


# ---------------------------------------------------------------------
# Authentication
# ---------------------------------------------------------------------


@pytest.mark.parametrize(
    "method,path",
    [
        ("GET", BASE_URL),
        ("GET", f"{BASE_URL}/{uuid4()}"),
        ("POST", BASE_URL),
        ("DELETE", f"{BASE_URL}/{uuid4()}"),
    ],
)
def test_anonymous_requests_are_rejected(
    wishlist_client: tuple[TestClient, Engine],
    method: str,
    path: str,
) -> None:
    client, _ = wishlist_client

    response = client.request(
        method,
        path,
        json={"country_code": "PT"} if method == "POST" else None,
        headers=ORIGIN,
    )

    assert response.status_code == 401


def test_mobile_authentication_supports_crud(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, _ = wishlist_client

    headers = login_mobile(client)

    created = post_wishlist(
        client,
        {"country_code": "PT"},
        headers=headers,
    )

    assert created.status_code == 201, created.text

    entry_id = created.json()["created"][0]["id"]

    listed = client.get(
        BASE_URL,
        headers=headers,
    )

    assert listed.status_code == 200
    assert listed.json()["total"] == 1

    retrieved = client.get(
        f"{BASE_URL}/{entry_id}",
        headers=headers,
    )

    assert retrieved.status_code == 200
    assert retrieved.json()["id"] == entry_id

    deleted = client.delete(
        f"{BASE_URL}/{entry_id}",
        headers=ORIGIN | headers,
    )

    assert deleted.status_code == 204

    after_delete = client.get(
        BASE_URL,
        headers=headers,
    )

    assert after_delete.json()["total"] == 0


# ---------------------------------------------------------------------
# GET
# ---------------------------------------------------------------------


def test_empty_wishlist(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, _ = wishlist_client

    login_web(client)

    response = client.get(BASE_URL)

    assert response.status_code == 200
    assert response.json() == {
        "items": [],
        "total": 0,
    }


def test_list_wishlist_entries(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, _ = wishlist_client

    login_web(client)

    create_country(client)

    city_response = post_wishlist(
        client,
        {"city_id": LISBON_ID},
    )

    assert city_response.status_code == 201

    response = client.get(BASE_URL)

    assert response.status_code == 200

    data = response.json()

    assert data["total"] == 2
    assert len(data["items"]) == 2

    assert {
        (
            entry["country_code"],
            entry["city_id"],
        )
        for entry in data["items"]
    } == {
        ("PT", None),
        (None, LISBON_ID),
    }


def test_get_owned_entry(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, _ = wishlist_client

    login_web(client)

    entry_id = create_country(client)

    response = client.get(f"{BASE_URL}/{entry_id}")

    assert response.status_code == 200

    data = response.json()

    assert data["id"] == entry_id
    assert data["country_code"] == "PT"
    assert data["city_id"] is None

    assert data["created_at"] is not None
    assert data["updated_at"] is not None


def test_get_missing_entry(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, _ = wishlist_client

    login_web(client)

    response = client.get(f"{BASE_URL}/{uuid4()}")

    assert response.status_code == 404


def test_invalid_entry_uuid(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, _ = wishlist_client

    login_web(client)

    response = client.get(f"{BASE_URL}/invalid-uuid")

    assert response.status_code == 422


# ---------------------------------------------------------------------
# POST: country and city
# ---------------------------------------------------------------------


def test_create_country(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, engine = wishlist_client

    login_web(client)

    response = post_wishlist(
        client,
        {"country_code": "PT"},
    )

    assert response.status_code == 201, response.text

    data = response.json()

    assert len(data["created"]) == 1
    assert data["existing"] == []

    entry = data["created"][0]

    assert entry["country_code"] == "PT"
    assert entry["city_id"] is None

    assert entry["id"] is not None
    assert entry["created_at"] is not None
    assert entry["updated_at"] is not None

    assert count_wishlist_entries(engine) == 1


def test_create_city_without_country(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, engine = wishlist_client

    login_web(client)

    response = post_wishlist(
        client,
        {"city_id": LISBON_ID},
    )

    assert response.status_code == 201, response.text

    data = response.json()

    assert len(data["created"]) == 1
    assert data["existing"] == []

    assert data["created"][0]["city_id"] == LISBON_ID
    assert data["created"][0]["country_code"] is None

    with Session(engine) as session:
        entries = session.scalars(select(WishlistEntry)).all()

        assert len(entries) == 1
        assert entries[0].city_id == LISBON_ID


def test_create_city_and_country(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, engine = wishlist_client

    login_web(client)

    response = post_wishlist(
        client,
        {
            "city_id": LISBON_ID,
            "include_country": True,
        },
    )

    assert response.status_code == 201, response.text

    data = response.json()

    assert len(data["created"]) == 2
    assert data["existing"] == []

    assert {
        (
            entry["country_code"],
            entry["city_id"],
        )
        for entry in data["created"]
    } == {
        ("PT", None),
        (None, LISBON_ID),
    }

    assert count_wishlist_entries(engine) == 2


def test_country_code_is_normalized(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, _ = wishlist_client

    login_web(client)

    response = post_wishlist(
        client,
        {"country_code": " pt "},
    )

    assert response.status_code == 201
    assert response.json()["created"][0]["country_code"] == "PT"


# ---------------------------------------------------------------------
# POST: idempotency
# ---------------------------------------------------------------------


def test_repeated_country_returns_existing(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, engine = wishlist_client

    login_web(client)

    original_id = create_country(client)

    response = post_wishlist(
        client,
        {"country_code": "PT"},
    )

    assert response.status_code == 200, response.text

    data = response.json()

    assert data["created"] == []
    assert len(data["existing"]) == 1

    assert data["existing"][0]["id"] == original_id
    assert count_wishlist_entries(engine) == 1


def test_repeated_city_returns_existing(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, engine = wishlist_client

    login_web(client)

    first = post_wishlist(
        client,
        {"city_id": LISBON_ID},
    )

    assert first.status_code == 201

    second = post_wishlist(
        client,
        {"city_id": LISBON_ID},
    )

    assert second.status_code == 200

    assert second.json()["created"] == []
    assert len(second.json()["existing"]) == 1

    assert count_wishlist_entries(engine) == 1


def test_existing_country_creates_only_city(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, engine = wishlist_client

    login_web(client)

    create_country(client)

    response = post_wishlist(
        client,
        {
            "city_id": LISBON_ID,
            "include_country": True,
        },
    )

    assert response.status_code == 201

    data = response.json()

    assert len(data["created"]) == 1
    assert len(data["existing"]) == 1

    assert data["created"][0]["city_id"] == LISBON_ID
    assert data["existing"][0]["country_code"] == "PT"

    assert count_wishlist_entries(engine) == 2


def test_existing_city_creates_only_country(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, engine = wishlist_client

    login_web(client)

    first = post_wishlist(
        client,
        {"city_id": LISBON_ID},
    )

    assert first.status_code == 201

    response = post_wishlist(
        client,
        {
            "city_id": LISBON_ID,
            "include_country": True,
        },
    )

    assert response.status_code == 201

    data = response.json()

    assert len(data["created"]) == 1
    assert len(data["existing"]) == 1

    assert data["created"][0]["country_code"] == "PT"
    assert data["existing"][0]["city_id"] == LISBON_ID

    assert count_wishlist_entries(engine) == 2


def test_both_existing_returns_200(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, engine = wishlist_client

    login_web(client)

    payload = {
        "city_id": LISBON_ID,
        "include_country": True,
    }

    first = post_wishlist(client, payload)

    assert first.status_code == 201

    second = post_wishlist(client, payload)

    assert second.status_code == 200

    data = second.json()

    assert data["created"] == []
    assert len(data["existing"]) == 2

    assert count_wishlist_entries(engine) == 2


# ---------------------------------------------------------------------
# POST: validation
# ---------------------------------------------------------------------


@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"country_code": None, "city_id": None},
        {"country_code": "PT", "city_id": LISBON_ID},
        {"country_code": "PT", "include_country": True},
        {"include_country": True},
        {"country_code": "PRT"},
        {"country_code": "12"},
        {"city_id": 0},
        {"city_id": -1},
        {"city_id": "2267057"},
        {"city_id": True},
        {"country_code": "PT", "notes": "Visit someday"},
        {"country_code": "PT", "started_on": "2027-01-01"},
    ],
)
def test_invalid_payload_returns_422(
    wishlist_client: tuple[TestClient, Engine],
    payload: dict,
) -> None:
    client, engine = wishlist_client

    login_web(client)

    response = post_wishlist(client, payload)

    assert response.status_code == 422, response.text
    assert count_wishlist_entries(engine) == 0


def test_unknown_country_returns_404(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, engine = wishlist_client

    login_web(client)

    response = post_wishlist(
        client,
        {"country_code": "XX"},
    )

    assert response.status_code == 404
    assert count_wishlist_entries(engine) == 0


def test_unknown_city_returns_404(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, engine = wishlist_client

    login_web(client)

    response = post_wishlist(
        client,
        {"city_id": 999999999},
    )

    assert response.status_code == 404
    assert count_wishlist_entries(engine) == 0


# ---------------------------------------------------------------------
# Multi-user isolation
# ---------------------------------------------------------------------


def test_users_have_independent_wishlists(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, engine = wishlist_client

    login_web(client, "goncalo")

    first_id = create_country(client)

    login_web(client, "anotheruser")

    other_list = client.get(BASE_URL)

    assert other_list.status_code == 200
    assert other_list.json()["items"] == []

    other_get = client.get(f"{BASE_URL}/{first_id}")

    assert other_get.status_code == 404

    other_delete = client.delete(
        f"{BASE_URL}/{first_id}",
        headers=ORIGIN,
    )

    assert other_delete.status_code == 404

    second_id = create_country(client)

    assert first_id != second_id
    assert count_wishlist_entries(engine) == 2

    login_web(client, "goncalo")

    original_list = client.get(BASE_URL)

    assert original_list.status_code == 200
    assert original_list.json()["total"] == 1
    assert original_list.json()["items"][0]["id"] == first_id


# ---------------------------------------------------------------------
# DELETE
# ---------------------------------------------------------------------


def test_delete_owned_entry(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, engine = wishlist_client

    login_web(client)

    entry_id = create_country(client)

    response = client.delete(
        f"{BASE_URL}/{entry_id}",
        headers=ORIGIN,
    )

    assert response.status_code == 204
    assert not response.content

    assert count_wishlist_entries(engine) == 0

    missing = client.get(f"{BASE_URL}/{entry_id}")

    assert missing.status_code == 404


def test_delete_missing_entry(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, _ = wishlist_client

    login_web(client)

    response = client.delete(
        f"{BASE_URL}/{uuid4()}",
        headers=ORIGIN,
    )

    assert response.status_code == 404


def test_delete_country_does_not_delete_city(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    client, engine = wishlist_client

    login_web(client)

    response = post_wishlist(
        client,
        {
            "city_id": LISBON_ID,
            "include_country": True,
        },
    )

    assert response.status_code == 201

    entries = response.json()["created"]

    country_id = next(entry["id"] for entry in entries if entry["country_code"] == "PT")

    deleted = client.delete(
        f"{BASE_URL}/{country_id}",
        headers=ORIGIN,
    )

    assert deleted.status_code == 204

    with Session(engine) as session:
        remaining = session.scalars(select(WishlistEntry)).all()

        assert len(remaining) == 1
        assert remaining[0].city_id == LISBON_ID


# ---------------------------------------------------------------------
# Domain independence
# ---------------------------------------------------------------------


def test_wishlist_does_not_create_been_or_lived_records(
    wishlist_client: tuple[TestClient, Engine],
) -> None:
    """Wishlist operations must not create visits or residences."""

    client, engine = wishlist_client

    login_web(client)

    response = post_wishlist(
        client,
        {
            "city_id": LISBON_ID,
            "include_country": True,
        },
    )

    assert response.status_code == 201

    with Session(engine) as session:
        assert session.scalars(select(CountryVisit)).all() == []

        assert session.scalars(select(CityVisit)).all() == []

        assert session.scalars(select(Residence)).all() == []

        assert len(session.scalars(select(WishlistEntry)).all()) == 2
