"""Integration tests for authenticated personal Flight endpoints."""

from collections.abc import Generator
from pathlib import Path
from uuid import UUID

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.security import hash_password
from app.db.base import Base
from app.db.session import create_database_engine, get_db
from app.main import create_app
from app.models.airline import Airline
from app.models.airport import Airport
from app.models.city import City  # noqa: F401
from app.models.city_visit import CityVisit
from app.models.country import Country
from app.models.country_visit import CountryVisit
from app.models.flight import Flight
from app.models.trip import Trip
from app.models.user import User


PASSWORD = "correct-password-123"

OWNER_LOGIN = "flight_owner"
OTHER_LOGIN = "flight_other"


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def flights_client(
    tmp_path: Path,
) -> Generator[TestClient, None, None]:
    engine = create_database_engine(f"sqlite:///{tmp_path / 'flights_api.db'}")

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

        # Persist countries before inserting airports.
        session.flush()

        session.add_all(
            [
                # -----------------------------------------------------------
                # Lisbon: timezone available
                # -----------------------------------------------------------
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
                    timezone_id="Europe/Lisbon",
                    type="large_airport",
                    scheduled_service=True,
                ),
                # -----------------------------------------------------------
                # Porto: timezone intentionally unavailable
                #
                # Used to verify that incomplete catalog data
                # never prevents access to a flight.
                # -----------------------------------------------------------
                Airport(
                    id=200,
                    ident="LPPR",
                    iata_code="OPO",
                    icao_code="LPPR",
                    name="Francisco de Sá Carneiro Airport",
                    municipality="Porto",
                    source_country_code="PT",
                    country_code="PT",
                    latitude=41.24,
                    longitude=-8.68,
                    timezone_id=None,
                    type="large_airport",
                    scheduled_service=True,
                ),
                # -----------------------------------------------------------
                # Barcelona: timezone available
                # -----------------------------------------------------------
                Airport(
                    id=300,
                    ident="LEBL",
                    iata_code="BCN",
                    icao_code="LEBL",
                    name="Barcelona El Prat Airport",
                    municipality="Barcelona",
                    source_country_code="ES",
                    country_code="ES",
                    latitude=41.2974,
                    longitude=2.0833,
                    timezone_id="Europe/Madrid",
                    type="large_airport",
                    scheduled_service=True,
                ),
                Airline(
                    id=10,
                    name="TAP Air Portugal",
                    iata_code="TP",
                    icao_code="TAP",
                    country_name="Portugal",
                    source_key="test:tap",
                ),
                User(
                    username=OWNER_LOGIN,
                    email="flight_owner@example.com",
                    display_name="Flight Owner",
                    password_hash=hash_password(PASSWORD),
                ),
                User(
                    username=OTHER_LOGIN,
                    email="flight_other@example.com",
                    display_name="Flight Other",
                    password_hash=hash_password(PASSWORD),
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


# ---------------------------------------------------------------------------
# Authentication helpers
# ---------------------------------------------------------------------------


def mobile_headers(
    client: TestClient,
    *,
    login: str = OWNER_LOGIN,
) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/mobile/login",
        json={
            "login": login,
            "password": PASSWORD,
        },
    )

    assert response.status_code == 200

    return {
        "Authorization": (f"Bearer {response.json()['access_token']}"),
    }


def web_login(
    client: TestClient,
    *,
    login: str = OWNER_LOGIN,
) -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={
            "login": login,
            "password": PASSWORD,
        },
    )

    assert response.status_code == 200


# ---------------------------------------------------------------------------
# Flight helpers
# ---------------------------------------------------------------------------


def flight_payload(
    **overrides: object,
) -> dict[str, object]:
    payload: dict[str, object] = {
        "departure_airport_id": 100,
        "arrival_airport_id": 200,
        "departure_on": "2025-09-10",
        "status": "flown",
    }

    payload.update(overrides)

    return payload


def create_flight(
    client: TestClient,
    *,
    headers: dict[str, str],
    **overrides: object,
) -> dict:
    response = client.post(
        "/api/v1/flights",
        headers=headers,
        json=flight_payload(**overrides),
    )

    assert response.status_code == 201, response.text

    return response.json()


def get_flight_details(
    client: TestClient,
    *,
    headers: dict[str, str],
    flight_id: str,
) -> dict:
    response = client.get(
        f"/api/v1/flights/{flight_id}",
        headers=headers,
    )

    assert response.status_code == 200, response.text

    return response.json()


# ---------------------------------------------------------------------------
# Authentication
# ---------------------------------------------------------------------------


def test_flights_require_authentication(
    flights_client: TestClient,
) -> None:
    assert flights_client.get("/api/v1/flights").status_code == 401

    assert (
        flights_client.get("/api/v1/flights/00000000-0000-0000-0000-000000000001").status_code
        == 401
    )

    assert (
        flights_client.post(
            "/api/v1/flights",
            json=flight_payload(),
        ).status_code
        == 401
    )


# ---------------------------------------------------------------------------
# Flight creation
# ---------------------------------------------------------------------------


def test_mobile_can_create_flight(
    flights_client: TestClient,
) -> None:
    headers = mobile_headers(flights_client)

    response = flights_client.post(
        "/api/v1/flights",
        headers=headers,
        json=flight_payload(
            airline_id=10,
            flight_number=" tp1920 ",
            seat="12a",
        ),
    )

    assert response.status_code == 201, response.text

    flight = response.json()

    UUID(flight["id"])

    assert flight["departure_airport_id"] == 100
    assert flight["arrival_airport_id"] == 200
    assert flight["airline_id"] == 10
    assert flight["flight_number"] == "TP1920"
    assert flight["seat"] == "12A"
    assert flight["status"] == "flown"
    assert flight["created_at"]
    assert flight["updated_at"]

    # POST retains its existing response contract.
    assert "timing" not in flight


def test_web_can_create_flight(
    flights_client: TestClient,
) -> None:
    web_login(flights_client)

    response = flights_client.post(
        "/api/v1/flights",
        headers={"Origin": "http://testserver"},
        json=flight_payload(),
    )

    assert response.status_code == 201, response.text


def test_can_create_flight_with_manual_airline(
    flights_client: TestClient,
) -> None:
    headers = mobile_headers(flights_client)

    flight = create_flight(
        flights_client,
        headers=headers,
        airline_name="Air Berlin",
    )

    assert flight["airline_id"] is None
    assert flight["airline_name"] == "Air Berlin"


@pytest.mark.parametrize(
    "changes",
    [
        {"departure_airport_id": 999999},
        {"arrival_airport_id": 999999},
        {"airline_id": 999999},
        {"arrival_airport_id": 100},
        {"status": "cancelled"},
        {
            "airline_id": 10,
            "airline_name": "Air Berlin",
        },
        {"arrival_time": "14:30"},
        {"user_id": ("00000000-0000-0000-0000-000000000001")},
    ],
)
def test_create_rejects_invalid_data(
    flights_client: TestClient,
    changes: dict,
) -> None:
    headers = mobile_headers(flights_client)

    response = flights_client.post(
        "/api/v1/flights",
        headers=headers,
        json=flight_payload(**changes),
    )

    assert response.status_code == 422, response.text


def test_create_requires_explicit_status(
    flights_client: TestClient,
) -> None:
    headers = mobile_headers(flights_client)

    payload = flight_payload()
    del payload["status"]

    response = flights_client.post(
        "/api/v1/flights",
        headers=headers,
        json=payload,
    )

    assert response.status_code == 422


# ---------------------------------------------------------------------------
# Flight retrieval
# ---------------------------------------------------------------------------


def test_can_get_owned_flight(
    flights_client: TestClient,
) -> None:
    headers = mobile_headers(flights_client)

    created = create_flight(
        flights_client,
        headers=headers,
    )

    response = flights_client.get(
        f"/api/v1/flights/{created['id']}",
        headers=headers,
    )

    assert response.status_code == 200

    body = response.json()

    assert body["id"] == created["id"]

    # Flight Details exposes calculated timing.
    assert "timing" in body


def test_cannot_get_another_users_flight(
    flights_client: TestClient,
) -> None:
    owner_headers = mobile_headers(flights_client)

    created = create_flight(
        flights_client,
        headers=owner_headers,
    )

    other_headers = mobile_headers(
        flights_client,
        login=OTHER_LOGIN,
    )

    response = flights_client.get(
        f"/api/v1/flights/{created['id']}",
        headers=other_headers,
    )

    assert response.status_code == 404


# ---------------------------------------------------------------------------
# Flight timing
# ---------------------------------------------------------------------------


def test_flight_details_calculates_duration_between_timezones(
    flights_client: TestClient,
) -> None:
    """LIS -> BCN must account for the one-hour difference."""

    headers = mobile_headers(flights_client)

    created = create_flight(
        flights_client,
        headers=headers,
        departure_airport_id=100,
        arrival_airport_id=300,
        departure_on="2026-10-10",
        departure_time="19:20",
        arrival_on="2026-10-10",
        arrival_time="22:15",
    )

    details = get_flight_details(
        flights_client,
        headers=headers,
        flight_id=created["id"],
    )

    assert details["timing"] == {
        "departure": {
            "status": "valid",
            "utc_offset_minutes": 60,
        },
        "arrival": {
            "status": "valid",
            "utc_offset_minutes": 120,
        },
        "duration_minutes": 115,
    }


def test_flight_details_uses_winter_timezone_offsets(
    flights_client: TestClient,
) -> None:
    """Offsets are calculated for the flight's actual date."""

    headers = mobile_headers(flights_client)

    created = create_flight(
        flights_client,
        headers=headers,
        departure_airport_id=100,
        arrival_airport_id=300,
        departure_on="2026-12-10",
        departure_time="19:20",
        arrival_on="2026-12-10",
        arrival_time="22:15",
    )

    details = get_flight_details(
        flights_client,
        headers=headers,
        flight_id=created["id"],
    )

    timing = details["timing"]

    assert timing["departure"]["status"] == "valid"
    assert timing["arrival"]["status"] == "valid"

    assert timing["departure"]["utc_offset_minutes"] == 0
    assert timing["arrival"]["utc_offset_minutes"] == 60

    assert timing["duration_minutes"] == 115


def test_flight_details_handles_missing_timezone(
    flights_client: TestClient,
) -> None:
    """Missing catalog timezone must not make the flight fail."""

    headers = mobile_headers(flights_client)

    # OPO intentionally has no timezone_id in this fixture.
    created = create_flight(
        flights_client,
        headers=headers,
        departure_airport_id=100,
        arrival_airport_id=200,
        departure_on="2026-10-10",
        departure_time="19:20",
        arrival_on="2026-10-10",
        arrival_time="20:20",
    )

    details = get_flight_details(
        flights_client,
        headers=headers,
        flight_id=created["id"],
    )

    assert details["timing"] == {
        "departure": {
            "status": "valid",
            "utc_offset_minutes": 60,
        },
        "arrival": {
            "status": "unavailable",
            "utc_offset_minutes": None,
        },
        "duration_minutes": None,
    }


def test_flight_details_handles_missing_schedule_times(
    flights_client: TestClient,
) -> None:
    """A flight can exist without complete schedule information."""

    headers = mobile_headers(flights_client)

    created = create_flight(
        flights_client,
        headers=headers,
        departure_airport_id=100,
        arrival_airport_id=300,
        departure_on="2026-10-10",
    )

    details = get_flight_details(
        flights_client,
        headers=headers,
        flight_id=created["id"],
    )

    assert details["timing"] == {
        "departure": {
            "status": "unavailable",
            "utc_offset_minutes": None,
        },
        "arrival": {
            "status": "unavailable",
            "utc_offset_minutes": None,
        },
        "duration_minutes": None,
    }


def test_flight_details_handles_missing_arrival_time(
    flights_client: TestClient,
) -> None:
    """Departure offset remains available without arrival time."""

    headers = mobile_headers(flights_client)

    created = create_flight(
        flights_client,
        headers=headers,
        departure_airport_id=100,
        arrival_airport_id=300,
        departure_on="2026-10-10",
        departure_time="19:20",
    )

    details = get_flight_details(
        flights_client,
        headers=headers,
        flight_id=created["id"],
    )

    timing = details["timing"]

    assert timing["departure"] == {
        "status": "valid",
        "utc_offset_minutes": 60,
    }

    assert timing["arrival"] == {
        "status": "unavailable",
        "utc_offset_minutes": None,
    }

    assert timing["duration_minutes"] is None


def test_flight_details_detects_ambiguous_local_time(
    flights_client: TestClient,
) -> None:
    """DST fallback must never produce a guessed duration."""

    headers = mobile_headers(flights_client)

    created = create_flight(
        flights_client,
        headers=headers,
        departure_airport_id=100,
        arrival_airport_id=300,
        departure_on="2026-10-25",
        departure_time="01:30",
        arrival_on="2026-10-25",
        arrival_time="05:00",
    )

    details = get_flight_details(
        flights_client,
        headers=headers,
        flight_id=created["id"],
    )

    timing = details["timing"]

    assert timing["departure"] == {
        "status": "ambiguous",
        "utc_offset_minutes": None,
    }

    assert timing["arrival"]["status"] == "valid"

    assert timing["duration_minutes"] is None


def test_flight_details_detects_nonexistent_local_time(
    flights_client: TestClient,
) -> None:
    """DST spring transition must not invent a UTC instant."""

    headers = mobile_headers(flights_client)

    created = create_flight(
        flights_client,
        headers=headers,
        departure_airport_id=100,
        arrival_airport_id=300,
        departure_on="2026-03-29",
        departure_time="01:30",
        arrival_on="2026-03-29",
        arrival_time="05:00",
    )

    details = get_flight_details(
        flights_client,
        headers=headers,
        flight_id=created["id"],
    )

    timing = details["timing"]

    assert timing["departure"] == {
        "status": "nonexistent",
        "utc_offset_minutes": None,
    }

    assert timing["arrival"]["status"] == "valid"

    assert timing["duration_minutes"] is None


def test_flight_details_does_not_report_negative_duration(
    flights_client: TestClient,
) -> None:
    """Inconsistent schedules must not produce negative durations."""

    headers = mobile_headers(flights_client)

    created = create_flight(
        flights_client,
        headers=headers,
        departure_airport_id=100,
        arrival_airport_id=300,
        departure_on="2026-10-10",
        departure_time="20:00",
        arrival_on="2026-10-10",
        arrival_time="18:00",
    )

    details = get_flight_details(
        flights_client,
        headers=headers,
        flight_id=created["id"],
    )

    assert details["timing"]["duration_minutes"] is None


# ---------------------------------------------------------------------------
# Flight listing
# ---------------------------------------------------------------------------


def test_list_returns_only_owned_flights(
    flights_client: TestClient,
) -> None:
    owner_headers = mobile_headers(flights_client)

    own = create_flight(
        flights_client,
        headers=owner_headers,
    )

    other_headers = mobile_headers(
        flights_client,
        login=OTHER_LOGIN,
    )

    create_flight(
        flights_client,
        headers=other_headers,
    )

    response = flights_client.get(
        "/api/v1/flights",
        headers=owner_headers,
    )

    assert response.status_code == 200

    body = response.json()

    assert body["total"] == 1
    assert body["limit"] == 20
    assert body["offset"] == 0

    assert [item["id"] for item in body["items"]] == [
        own["id"],
    ]


def test_flight_list_does_not_include_timing(
    flights_client: TestClient,
) -> None:
    """Timing is calculated only for the detail endpoint."""

    headers = mobile_headers(flights_client)

    create_flight(
        flights_client,
        headers=headers,
        departure_airport_id=100,
        arrival_airport_id=300,
        departure_on="2026-10-10",
        departure_time="19:20",
        arrival_on="2026-10-10",
        arrival_time="22:15",
    )

    response = flights_client.get(
        "/api/v1/flights",
        headers=headers,
    )

    assert response.status_code == 200

    items = response.json()["items"]

    assert len(items) == 1
    assert "timing" not in items[0]


def test_list_filters_by_status(
    flights_client: TestClient,
) -> None:
    headers = mobile_headers(flights_client)

    create_flight(
        flights_client,
        headers=headers,
        status="flown",
    )

    planned = create_flight(
        flights_client,
        headers=headers,
        departure_on="2027-06-10",
        status="planned",
    )

    response = flights_client.get(
        "/api/v1/flights",
        params={"status": "planned"},
        headers=headers,
    )

    assert response.status_code == 200

    body = response.json()

    assert body["total"] == 1
    assert body["items"][0]["id"] == planned["id"]


def test_list_supports_pagination(
    flights_client: TestClient,
) -> None:
    headers = mobile_headers(flights_client)

    for year in (2023, 2024, 2025):
        create_flight(
            flights_client,
            headers=headers,
            departure_on=f"{year}-09-10",
        )

    response = flights_client.get(
        "/api/v1/flights",
        params={"limit": 1, "offset": 1},
        headers=headers,
    )

    assert response.status_code == 200

    body = response.json()

    assert body["total"] == 3
    assert body["limit"] == 1
    assert body["offset"] == 1
    assert len(body["items"]) == 1

    assert body["items"][0]["departure_on"] == "2024-09-10"


# ---------------------------------------------------------------------------
# Flight updates
# ---------------------------------------------------------------------------


def test_can_patch_owned_flight(
    flights_client: TestClient,
) -> None:
    headers = mobile_headers(flights_client)

    created = create_flight(
        flights_client,
        headers=headers,
        airline_id=10,
    )

    response = flights_client.patch(
        f"/api/v1/flights/{created['id']}",
        headers=headers,
        json={
            "airline_id": None,
            "airline_name": "Air Berlin",
            "seat": "14c",
        },
    )

    assert response.status_code == 200, response.text

    updated = response.json()

    assert updated["airline_id"] is None
    assert updated["airline_name"] == "Air Berlin"
    assert updated["seat"] == "14C"

    # PATCH keeps its original response contract.
    assert "timing" not in updated


def test_patch_rejects_invalid_final_state(
    flights_client: TestClient,
) -> None:
    headers = mobile_headers(flights_client)

    created = create_flight(
        flights_client,
        headers=headers,
        airline_id=10,
    )

    response = flights_client.patch(
        f"/api/v1/flights/{created['id']}",
        headers=headers,
        json={
            "airline_name": "Air Berlin",
        },
    )

    assert response.status_code == 422

    persisted = flights_client.get(
        f"/api/v1/flights/{created['id']}",
        headers=headers,
    )

    assert persisted.status_code == 200

    assert persisted.json()["airline_id"] == 10
    assert persisted.json()["airline_name"] is None


def test_cannot_patch_another_users_flight(
    flights_client: TestClient,
) -> None:
    owner_headers = mobile_headers(flights_client)

    created = create_flight(
        flights_client,
        headers=owner_headers,
    )

    other_headers = mobile_headers(
        flights_client,
        login=OTHER_LOGIN,
    )

    response = flights_client.patch(
        f"/api/v1/flights/{created['id']}",
        headers=other_headers,
        json={"seat": "12A"},
    )

    assert response.status_code == 404


# ---------------------------------------------------------------------------
# Flight deletion
# ---------------------------------------------------------------------------


def test_can_delete_owned_flight(
    flights_client: TestClient,
) -> None:
    headers = mobile_headers(flights_client)

    created = create_flight(
        flights_client,
        headers=headers,
    )

    response = flights_client.delete(
        f"/api/v1/flights/{created['id']}",
        headers=headers,
    )

    assert response.status_code == 204
    assert response.content == b""

    response = flights_client.get(
        f"/api/v1/flights/{created['id']}",
        headers=headers,
    )

    assert response.status_code == 404


def test_cannot_delete_another_users_flight(
    flights_client: TestClient,
) -> None:
    owner_headers = mobile_headers(flights_client)

    created = create_flight(
        flights_client,
        headers=owner_headers,
    )

    other_headers = mobile_headers(
        flights_client,
        login=OTHER_LOGIN,
    )

    response = flights_client.delete(
        f"/api/v1/flights/{created['id']}",
        headers=other_headers,
    )

    assert response.status_code == 404

    persisted = flights_client.get(
        f"/api/v1/flights/{created['id']}",
        headers=owner_headers,
    )

    assert persisted.status_code == 200


# ---------------------------------------------------------------------------
# Domain invariants
# ---------------------------------------------------------------------------


def test_flight_creation_does_not_create_visits_or_trips(
    flights_client: TestClient,
) -> None:
    headers = mobile_headers(flights_client)

    create_flight(
        flights_client,
        headers=headers,
    )

    visits = flights_client.get(
        "/api/v1/country-visits",
        headers=headers,
    )

    trips = flights_client.get(
        "/api/v1/trips",
        headers=headers,
    )

    assert visits.status_code == 200
    assert trips.status_code == 200

    assert visits.json()["total"] == 0
    assert trips.json()["total"] == 0


# ---------------------------------------------------------------------------
# CSRF protection
# ---------------------------------------------------------------------------


def test_web_flight_creation_rejects_untrusted_origin(
    flights_client: TestClient,
) -> None:
    web_login(flights_client)

    response = flights_client.post(
        "/api/v1/flights",
        headers={
            "Origin": "https://untrusted.example",
        },
        json=flight_payload(),
    )

    assert response.status_code == 403
