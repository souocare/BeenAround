"""Integration tests for historical residence REST endpoints."""

from collections.abc import Generator
from datetime import date
from pathlib import Path
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
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


TEST_PASSWORD = "correct-password-123"

LISBON_ID = 2267057
MADRID_ID = 3117735

BASE_URL = "/api/v1/residences"
ORIGIN = {"Origin": "http://testserver"}


@pytest.fixture
def residences_client(
    tmp_path: Path,
) -> Generator[TestClient, None, None]:
    """Create an isolated API client backed by a temporary SQLite database."""

    engine = create_database_engine(f"sqlite:///{tmp_path / 'residences_api.db'}")

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
        yield client

    app.dependency_overrides.clear()
    engine.dispose()


def login_web(
    client: TestClient,
    username: str = "goncalo",
) -> None:
    """Authenticate using a Web session cookie."""

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
    """Authenticate and return a Mobile Bearer token."""

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


def residence_payload(
    *,
    country_code: str = "PT",
    city_id: int | None = LISBON_ID,
    started_on: str = "2020-01-01",
    ended_on: str = "2023-12-01",
    start_precision: str = "month",
    end_precision: str = "month",
) -> dict:
    """Build a valid historical residence request."""

    return {
        "country_code": country_code,
        "city_id": city_id,
        "started_on": started_on,
        "started_on_precision": start_precision,
        "ended_on": ended_on,
        "ended_on_precision": end_precision,
    }


def create_residence(
    client: TestClient,
    *,
    payload: dict | None = None,
    headers: dict[str, str] | None = None,
) -> str:
    """Create a residence and return its identifier."""

    response = client.post(
        BASE_URL,
        json=payload if payload is not None else residence_payload(),
        headers=ORIGIN | (headers or {}),
    )

    assert response.status_code == 201, response.text

    return response.json()["id"]


def get_overlap_confirmation(response) -> dict:
    """Extract the confirmation snapshot from an overlap conflict."""

    assert response.status_code == 409

    detail = response.json()["detail"]

    assert detail["code"] == "RESIDENCE_PERIOD_OVERLAP"

    return {
        "requested": detail["requested"],
        "overlaps": detail["overlaps"],
        "expected_target": detail["expected_target"],
    }


def test_residences_require_authentication(
    residences_client: TestClient,
) -> None:
    """Unauthenticated requests cannot access residence records."""

    client = residences_client
    residence_id = str(uuid4())

    assert client.get(BASE_URL).status_code == 401

    assert client.get(f"{BASE_URL}/{residence_id}").status_code == 401

    assert (
        client.post(
            BASE_URL,
            json=residence_payload(),
            headers=ORIGIN,
        ).status_code
        == 401
    )

    assert (
        client.patch(
            f"{BASE_URL}/{residence_id}",
            json={"city_id": None},
            headers=ORIGIN,
        ).status_code
        == 401
    )

    assert (
        client.delete(
            f"{BASE_URL}/{residence_id}",
            headers=ORIGIN,
        ).status_code
        == 401
    )


def test_web_user_can_create_residence(
    residences_client: TestClient,
) -> None:
    """A Web user can register a historical city residence."""

    login_web(residences_client)

    response = residences_client.post(
        BASE_URL,
        json=residence_payload(),
        headers=ORIGIN,
    )

    assert response.status_code == 201

    data = response.json()

    assert data["id"]
    assert data["country_code"] == "PT"
    assert data["city_id"] == LISBON_ID

    assert data["started_on"] == "2020-01-01"
    assert data["started_on_precision"] == "month"

    assert data["ended_on"] == "2023-12-01"
    assert data["ended_on_precision"] == "month"

    assert data["created_at"]
    assert data["updated_at"]


def test_mobile_user_can_create_residence(
    residences_client: TestClient,
) -> None:
    """Mobile authentication must support residence creation."""

    headers = login_mobile(residences_client)

    response = residences_client.post(
        BASE_URL,
        json=residence_payload(),
        headers=headers,
    )

    assert response.status_code == 201

    assert response.json()["country_code"] == "PT"


def test_can_create_country_only_residence(
    residences_client: TestClient,
) -> None:
    """Residence registration does not require a city."""

    login_web(residences_client)

    residence_id = create_residence(
        residences_client,
        payload=residence_payload(city_id=None),
    )

    response = residences_client.get(f"{BASE_URL}/{residence_id}")

    assert response.status_code == 200
    assert response.json()["country_code"] == "PT"
    assert response.json()["city_id"] is None


def test_list_residences(
    residences_client: TestClient,
) -> None:
    """The authenticated user can list their residences."""

    login_web(residences_client)

    first_id = create_residence(residences_client)

    second_id = create_residence(
        residences_client,
        payload=residence_payload(
            country_code="ES",
            city_id=MADRID_ID,
            started_on="2024-01-01",
            ended_on="2025-01-01",
        ),
    )

    response = residences_client.get(BASE_URL)

    assert response.status_code == 200

    data = response.json()

    assert data["total"] == 2
    assert len(data["items"]) == 2

    assert {item["id"] for item in data["items"]} == {first_id, second_id}


def test_users_cannot_access_other_residences(
    residences_client: TestClient,
) -> None:
    """User isolation applies to listing, reading, updating and deleting."""

    login_web(residences_client, username="goncalo")

    residence_id = create_residence(residences_client)

    login_web(residences_client, username="anotheruser")

    listing = residences_client.get(BASE_URL)

    assert listing.status_code == 200
    assert listing.json()["total"] == 0

    assert residences_client.get(f"{BASE_URL}/{residence_id}").status_code == 404

    assert (
        residences_client.patch(
            f"{BASE_URL}/{residence_id}",
            json={"city_id": None},
            headers=ORIGIN,
        ).status_code
        == 404
    )

    assert (
        residences_client.delete(
            f"{BASE_URL}/{residence_id}",
            headers=ORIGIN,
        ).status_code
        == 404
    )


def test_create_rejects_unknown_country(
    residences_client: TestClient,
) -> None:
    login_web(residences_client)

    response = residences_client.post(
        BASE_URL,
        json=residence_payload(
            country_code="XX",
            city_id=None,
        ),
        headers=ORIGIN,
    )

    assert response.status_code == 404
    assert response.json()["detail"] == "Country not found."


def test_create_rejects_unknown_city(
    residences_client: TestClient,
) -> None:
    login_web(residences_client)

    response = residences_client.post(
        BASE_URL,
        json=residence_payload(city_id=999999999),
        headers=ORIGIN,
    )

    assert response.status_code == 404
    assert response.json()["detail"] == "City not found."


def test_create_rejects_city_country_mismatch(
    residences_client: TestClient,
) -> None:
    login_web(residences_client)

    response = residences_client.post(
        BASE_URL,
        json=residence_payload(
            country_code="ES",
            city_id=LISBON_ID,
        ),
        headers=ORIGIN,
    )

    assert response.status_code == 422


@pytest.mark.parametrize(
    "field",
    [
        "started_on_precision",
        "ended_on_precision",
    ],
)
def test_create_rejects_year_precision(
    residences_client: TestClient,
    field: str,
) -> None:
    login_web(residences_client)

    payload = residence_payload()
    payload[field] = "year"

    response = residences_client.post(
        BASE_URL,
        json=payload,
        headers=ORIGIN,
    )

    assert response.status_code == 422


def test_create_rejects_invalid_date_range(
    residences_client: TestClient,
) -> None:
    login_web(residences_client)

    response = residences_client.post(
        BASE_URL,
        json=residence_payload(
            started_on="2025-01-01",
            ended_on="2020-01-01",
        ),
        headers=ORIGIN,
    )

    assert response.status_code == 422


def test_create_requires_overlap_confirmation(
    residences_client: TestClient,
) -> None:
    """An overlapping residence cannot be saved silently."""

    login_web(residences_client)

    existing_id = create_residence(residences_client)

    response = residences_client.post(
        BASE_URL,
        json=residence_payload(
            country_code="ES",
            city_id=MADRID_ID,
            started_on="2022-01-01",
            ended_on="2022-12-01",
        ),
        headers=ORIGIN,
    )

    confirmation = get_overlap_confirmation(response)

    assert len(confirmation["overlaps"]) == 1

    overlap = confirmation["overlaps"][0]

    assert overlap["residence_id"] == existing_id
    assert overlap["kind"] == "certain"

    assert confirmation["requested"]["country_code"] == "ES"
    assert confirmation["expected_target"] is None

    listing = residences_client.get(BASE_URL)

    assert listing.json()["total"] == 1


def test_create_accepts_exact_overlap_confirmation(
    residences_client: TestClient,
) -> None:
    """A matching confirmation authorizes the requested overlap."""

    login_web(residences_client)

    create_residence(residences_client)

    payload = residence_payload(
        country_code="ES",
        city_id=MADRID_ID,
        started_on="2022-01-01",
        ended_on="2022-12-01",
    )

    conflict = residences_client.post(
        BASE_URL,
        json=payload,
        headers=ORIGIN,
    )

    confirmation = get_overlap_confirmation(conflict)

    confirmed_response = residences_client.post(
        BASE_URL,
        json=payload
        | {
            "overlap_confirmation": confirmation,
        },
        headers=ORIGIN,
    )

    assert confirmed_response.status_code == 201
    assert confirmed_response.json()["country_code"] == "ES"

    listing = residences_client.get(BASE_URL)

    assert listing.json()["total"] == 2

def test_patch_note_on_overlapping_residence_without_reconfirmation(
    residences_client: TestClient,
) -> None:
    """Editing only a note must not require confirming existing overlaps."""

    login_web(residences_client)

    # Create the first residence.
    first_id = create_residence(residences_client)

    # Propose a second, overlapping residence.
    second_payload = residence_payload(
        country_code="ES",
        city_id=MADRID_ID,
        started_on="2022-01-01",
        ended_on="2022-12-01",
    )

    conflict = residences_client.post(
        BASE_URL,
        json=second_payload,
        headers=ORIGIN,
    )

    confirmation = get_overlap_confirmation(conflict)

    # Explicitly confirm the second residence.
    confirmed = residences_client.post(
        BASE_URL,
        json=second_payload
        | {
            "overlap_confirmation": confirmation,
        },
        headers=ORIGIN,
    )

    assert confirmed.status_code == 201, confirmed.text

    second_id = confirmed.json()["id"]

    # Read the original state before editing.
    first_before_response = residences_client.get(
        f"{BASE_URL}/{first_id}",
    )
    second_before_response = residences_client.get(
        f"{BASE_URL}/{second_id}",
    )

    assert first_before_response.status_code == 200
    assert second_before_response.status_code == 200

    first_before = first_before_response.json()
    second_before = second_before_response.json()

    # Only update the first residence's note.
    # No overlap confirmation is provided.
    updated = residences_client.patch(
        f"{BASE_URL}/{first_id}",
        json={
            "note": "Updated without changing my residence period.",
        },
        headers=ORIGIN,
    )

    assert updated.status_code == 200, updated.text

    updated_data = updated.json()

    assert updated_data["note"] == (
        "Updated without changing my residence period."
    )

    # The destination and date range remain unchanged.
    for field in (
        "country_code",
        "city_id",
        "started_on",
        "started_on_precision",
        "ended_on",
        "ended_on_precision",
    ):
        assert updated_data[field] == first_before[field]

    # The second residence must remain completely untouched.
    second_after_response = residences_client.get(
        f"{BASE_URL}/{second_id}",
    )

    assert second_after_response.status_code == 200
    assert second_after_response.json() == second_before

    # Both residence records must still exist.
    listing = residences_client.get(BASE_URL)

    assert listing.status_code == 200
    assert listing.json()["total"] == 2

def test_create_rejects_stale_overlap_confirmation(
    residences_client: TestClient,
) -> None:
    """Changing an existing overlap invalidates its old confirmation."""

    login_web(residences_client)

    existing_id = create_residence(residences_client)

    payload = residence_payload(
        country_code="ES",
        city_id=MADRID_ID,
        started_on="2022-01-01",
        ended_on="2022-12-01",
    )

    conflict = residences_client.post(
        BASE_URL,
        json=payload,
        headers=ORIGIN,
    )

    confirmation = get_overlap_confirmation(conflict)

    update_response = residences_client.patch(
        f"{BASE_URL}/{existing_id}",
        json={
            "ended_on": "2024-12-01",
            "ended_on_precision": "month",
        },
        headers=ORIGIN,
    )

    assert update_response.status_code == 200

    response = residences_client.post(
        BASE_URL,
        json=payload
        | {
            "overlap_confirmation": confirmation,
        },
        headers=ORIGIN,
    )

    assert response.status_code == 409

    assert response.json()["detail"]["code"] == "RESIDENCE_OVERLAP_CONFIRMATION_STALE"

    assert residences_client.get(BASE_URL).json()["total"] == 1


def test_create_rejects_confirmation_for_different_request(
    residences_client: TestClient,
) -> None:
    """A confirmation cannot authorize a different destination or period."""

    login_web(residences_client)

    create_residence(residences_client)

    original_payload = residence_payload(
        country_code="ES",
        city_id=MADRID_ID,
        started_on="2022-01-01",
        ended_on="2022-12-01",
    )

    conflict = residences_client.post(
        BASE_URL,
        json=original_payload,
        headers=ORIGIN,
    )

    confirmation = get_overlap_confirmation(conflict)

    changed_payload = residence_payload(
        country_code="PT",
        city_id=None,
        started_on="2022-01-01",
        ended_on="2022-12-01",
    )

    response = residences_client.post(
        BASE_URL,
        json=changed_payload
        | {
            "overlap_confirmation": confirmation,
        },
        headers=ORIGIN,
    )

    assert response.status_code == 409

    assert response.json()["detail"]["code"] == "RESIDENCE_OVERLAP_CONFIRMATION_STALE"


def test_patch_preserves_omitted_fields(
    residences_client: TestClient,
) -> None:
    """PATCH must not replace fields omitted by the client."""

    login_web(residences_client)

    residence_id = create_residence(residences_client)

    response = residences_client.patch(
        f"{BASE_URL}/{residence_id}",
        json={
            "ended_on": "2024-06-01",
            "ended_on_precision": "month",
        },
        headers=ORIGIN,
    )

    assert response.status_code == 200

    data = response.json()

    assert data["id"] == residence_id
    assert data["country_code"] == "PT"
    assert data["city_id"] == LISBON_ID

    assert data["started_on"] == "2020-01-01"
    assert data["ended_on"] == "2024-06-01"


def test_patch_can_remove_city(
    residences_client: TestClient,
) -> None:
    """Explicit city_id=null converts a city residence into a country residence."""

    login_web(residences_client)

    residence_id = create_residence(residences_client)

    response = residences_client.patch(
        f"{BASE_URL}/{residence_id}",
        json={"city_id": None},
        headers=ORIGIN,
    )

    assert response.status_code == 200
    assert response.json()["city_id"] is None
    assert response.json()["country_code"] == "PT"


def test_patch_requires_overlap_confirmation(
    residences_client: TestClient,
) -> None:
    """Updating one residence must not silently overlap another."""

    login_web(residences_client)

    create_residence(residences_client)

    second_id = create_residence(
        residences_client,
        payload=residence_payload(
            country_code="ES",
            city_id=MADRID_ID,
            started_on="2025-01-01",
            ended_on="2026-01-01",
        ),
    )

    response = residences_client.patch(
        f"{BASE_URL}/{second_id}",
        json={
            "started_on": "2022-01-01",
            "started_on_precision": "month",
        },
        headers=ORIGIN,
    )

    confirmation = get_overlap_confirmation(response)

    assert len(confirmation["overlaps"]) == 1

    assert confirmation["expected_target"] is not None
    assert confirmation["expected_target"]["residence_id"] == second_id

    unchanged = residences_client.get(f"{BASE_URL}/{second_id}")

    assert unchanged.json()["started_on"] == "2025-01-01"


def test_patch_accepts_exact_overlap_confirmation(
    residences_client: TestClient,
) -> None:
    """An exact confirmation permits updating an overlapping residence."""

    login_web(residences_client)

    create_residence(residences_client)

    second_id = create_residence(
        residences_client,
        payload=residence_payload(
            country_code="ES",
            city_id=MADRID_ID,
            started_on="2025-01-01",
            ended_on="2026-01-01",
        ),
    )

    changes = {
        "started_on": "2022-01-01",
        "started_on_precision": "month",
    }

    conflict = residences_client.patch(
        f"{BASE_URL}/{second_id}",
        json=changes,
        headers=ORIGIN,
    )

    confirmation = get_overlap_confirmation(conflict)

    response = residences_client.patch(
        f"{BASE_URL}/{second_id}",
        json=changes
        | {
            "overlap_confirmation": confirmation,
        },
        headers=ORIGIN,
    )

    assert response.status_code == 200
    assert response.json()["started_on"] == "2022-01-01"
    assert response.json()["ended_on"] == "2026-01-01"


def test_patch_rejects_stale_target(
    residences_client: TestClient,
) -> None:
    """Changing the edited residence invalidates its confirmation."""

    login_web(residences_client)

    create_residence(residences_client)

    second_id = create_residence(
        residences_client,
        payload=residence_payload(
            country_code="ES",
            city_id=MADRID_ID,
            started_on="2025-01-01",
            ended_on="2026-01-01",
        ),
    )

    changes = {
        "started_on": "2022-01-01",
        "started_on_precision": "month",
    }

    conflict = residences_client.patch(
        f"{BASE_URL}/{second_id}",
        json=changes,
        headers=ORIGIN,
    )

    confirmation = get_overlap_confirmation(conflict)

    changed_target = residences_client.patch(
        f"{BASE_URL}/{second_id}",
        json={
            "ended_on": "2027-01-01",
            "ended_on_precision": "month",
        },
        headers=ORIGIN,
    )

    assert changed_target.status_code == 200

    response = residences_client.patch(
        f"{BASE_URL}/{second_id}",
        json=changes
        | {
            "overlap_confirmation": confirmation,
        },
        headers=ORIGIN,
    )

    assert response.status_code == 409

    assert response.json()["detail"]["code"] == "RESIDENCE_OVERLAP_CONFIRMATION_STALE"


def test_delete_owned_residence(
    residences_client: TestClient,
) -> None:
    """Deleting a residence returns 204 and removes only that record."""

    login_web(residences_client)

    residence_id = create_residence(residences_client)

    response = residences_client.delete(
        f"{BASE_URL}/{residence_id}",
        headers=ORIGIN,
    )

    assert response.status_code == 204

    assert residences_client.get(f"{BASE_URL}/{residence_id}").status_code == 404

    assert residences_client.get(BASE_URL).json()["total"] == 0


def test_delete_nonexistent_residence(
    residences_client: TestClient,
) -> None:
    login_web(residences_client)

    response = residences_client.delete(
        f"{BASE_URL}/{uuid4()}",
        headers=ORIGIN,
    )

    assert response.status_code == 404


def test_residence_does_not_create_been_records(
    residences_client: TestClient,
) -> None:
    """Lived must remain independent of visited countries and cities."""

    login_web(residences_client)

    create_residence(residences_client)

    response = residences_client.get(BASE_URL)

    assert response.status_code == 200
    assert response.json()["total"] == 1

    country_visits = residences_client.get("/api/v1/country-visits")

    city_visits = residences_client.get("/api/v1/city-visits")

    assert country_visits.status_code == 200
    assert city_visits.status_code == 200

    assert country_visits.json()["total"] == 0
    assert city_visits.json()["total"] == 0


def test_create_residence_with_note(
    residences_client: TestClient,
) -> None:
    client = residences_client

    login_web(client)

    payload = residence_payload(
        city_id=None,
    )

    payload["note"] = "Lived here during university."

    response = client.post(
        BASE_URL,
        json=payload,
        headers=ORIGIN,
    )

    assert response.status_code == 201, response.text

    data = response.json()

    assert data["note"] == "Lived here during university."
    assert data["country_code"] == "PT"


def test_patch_residence_note_only(
    residences_client: TestClient,
) -> None:
    client = residences_client

    login_web(client)

    entry_id = create_residence(client)

    response = client.patch(
        f"{BASE_URL}/{entry_id}",
        json={
            "note": "My first apartment.",
        },
        headers=ORIGIN,
    )

    assert response.status_code == 200, response.text

    data = response.json()

    assert data["note"] == "My first apartment."
    assert data["started_on"] == "2020-01-01"
    assert data["ended_on"] == "2023-12-01"


def test_patch_residence_note_to_null(
    residences_client: TestClient,
) -> None:
    client = residences_client

    login_web(client)

    payload = residence_payload()
    payload["note"] = "Original note."

    entry_id = create_residence(
        client,
        payload=payload,
    )

    response = client.patch(
        f"{BASE_URL}/{entry_id}",
        json={"note": None},
        headers=ORIGIN,
    )

    assert response.status_code == 200
    assert response.json()["note"] is None


def test_patch_residence_rejects_long_note(
    residences_client: TestClient,
) -> None:
    client = residences_client

    login_web(client)

    entry_id = create_residence(client)

    response = client.patch(
        f"{BASE_URL}/{entry_id}",
        json={
            "note": "A" * 1001,
        },
        headers=ORIGIN,
    )

    assert response.status_code == 422


def test_patch_residence_dates_preserves_note(
    residences_client: TestClient,
) -> None:
    client = residences_client

    login_web(client)

    payload = residence_payload()
    payload["note"] = "Keep this note."

    entry_id = create_residence(
        client,
        payload=payload,
    )

    response = client.patch(
        f"{BASE_URL}/{entry_id}",
        json={
            "ended_on": "2024-06-01",
            "ended_on_precision": "month",
        },
        headers=ORIGIN,
    )

    assert response.status_code == 200, response.text
    assert response.json()["note"] == "Keep this note."
