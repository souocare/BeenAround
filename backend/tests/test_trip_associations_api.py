"""Integration tests for Trip visit association endpoints."""

from collections.abc import Generator
from datetime import date
from pathlib import Path
from uuid import UUID, uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import Engine, func, select
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
from app.models.trip import Trip
from app.models.trip_city_visit import TripCityVisit
from app.models.trip_country_visit import TripCountryVisit
from app.models.user import User


TEST_PASSWORD = "correct-password-123"
ORIGIN = {"Origin": "http://testserver"}

BASE_URL = "/api/v1/trips"

LISBON_ID = 2267057


@pytest.fixture
def associations_client(
    tmp_path: Path,
) -> Generator[
    tuple[TestClient, Engine, dict[str, str]],
    None,
    None,
]:
    """Create an isolated database with two users and travel records."""

    engine = create_database_engine(f"sqlite:///{tmp_path / 'trip_associations_api.db'}")

    Base.metadata.create_all(engine)

    with Session(engine) as session:
        session.add(
            Country(
                code="PT",
                name="Portugal",
                alpha3_code="PRT",
                continent="EU",
            )
        )

        session.flush()

        session.add(
            City(
                id=LISBON_ID,
                country_code="PT",
                name="Lisbon",
                ascii_name="Lisbon",
                latitude=38.71667,
                longitude=-9.13333,
                population=517802,
                feature_code="PPLC",
            )
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

        own_trip = Trip(
            user_id=first_user.id,
            name="Portugal 2025",
        )

        other_trip = Trip(
            user_id=second_user.id,
            name="Private Trip",
        )

        own_country_visit = CountryVisit(
            user_id=first_user.id,
            country_code="PT",
            started_on=date(2025, 7, 10),
            started_on_precision="day",
            ended_on=date(2025, 7, 15),
            ended_on_precision="day",
        )

        other_country_visit = CountryVisit(
            user_id=second_user.id,
            country_code="PT",
            started_on=date(2024, 8, 10),
            started_on_precision="day",
            ended_on=date(2024, 8, 15),
            ended_on_precision="day",
        )

        own_city_visit = CityVisit(
            user_id=first_user.id,
            city_id=LISBON_ID,
            started_on=date(2025, 7, 11),
            started_on_precision="day",
            ended_on=date(2025, 7, 14),
            ended_on_precision="day",
        )

        other_city_visit = CityVisit(
            user_id=second_user.id,
            city_id=LISBON_ID,
            started_on=date(2024, 8, 11),
            started_on_precision="day",
            ended_on=date(2024, 8, 14),
            ended_on_precision="day",
        )

        session.add_all(
            [
                own_trip,
                other_trip,
                own_country_visit,
                other_country_visit,
                own_city_visit,
                other_city_visit,
            ]
        )

        session.flush()

        ids = {
            "own_trip": str(own_trip.id),
            "other_trip": str(other_trip.id),
            "own_country_visit": str(own_country_visit.id),
            "other_country_visit": str(other_country_visit.id),
            "own_city_visit": str(own_city_visit.id),
            "other_city_visit": str(other_city_visit.id),
        }

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
        yield client, engine, ids

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
        headers=ORIGIN,
    )

    assert response.status_code == 200, response.text


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

    assert response.status_code == 200, response.text

    return {
        "Authorization": f"Bearer {response.json()['access_token']}",
    }


def country_url(trip_id: str) -> str:
    return f"{BASE_URL}/{trip_id}/country-visits"


def city_url(trip_id: str) -> str:
    return f"{BASE_URL}/{trip_id}/city-visits"


# ---------------------------------------------------------
# Authentication
# ---------------------------------------------------------


@pytest.mark.parametrize(
    "method,suffix",
    [
        ("GET", "country-visits"),
        ("POST", "country-visits"),
        ("DELETE", f"country-visits/{uuid4()}"),
        ("GET", "city-visits"),
        ("POST", "city-visits"),
        ("DELETE", f"city-visits/{uuid4()}"),
    ],
)
def test_associations_require_authentication(
    associations_client,
    method: str,
    suffix: str,
) -> None:
    client, _, ids = associations_client

    response = client.request(
        method,
        f"{BASE_URL}/{ids['own_trip']}/{suffix}",
        headers=ORIGIN,
    )

    assert response.status_code == 401


def test_mobile_authentication_can_list_associations(
    associations_client,
) -> None:
    client, _, ids = associations_client

    headers = login_mobile(client)

    response = client.get(
        country_url(ids["own_trip"]),
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["total"] == 0


# ---------------------------------------------------------
# Empty lists
# ---------------------------------------------------------


def test_new_trip_has_no_associations(
    associations_client,
) -> None:
    client, _, ids = associations_client

    login_web(client)

    for url in (
        country_url(ids["own_trip"]),
        city_url(ids["own_trip"]),
    ):
        response = client.get(url)

        assert response.status_code == 200
        assert response.json() == {
            "items": [],
            "total": 0,
        }


# ---------------------------------------------------------
# Country associations
# ---------------------------------------------------------


def test_country_visit_can_be_associated(
    associations_client,
) -> None:
    client, engine, ids = associations_client

    login_web(client)

    response = client.post(
        country_url(ids["own_trip"]),
        json={
            "country_visit_id": ids["own_country_visit"],
        },
        headers=ORIGIN,
    )

    assert response.status_code == 201, response.text

    assert response.json() == {
        "trip_id": ids["own_trip"],
        "visit_id": ids["own_country_visit"],
    }

    listed = client.get(
        country_url(ids["own_trip"]),
    )

    assert listed.status_code == 200

    body = listed.json()

    assert body["total"] == 1
    assert body["items"][0]["id"] == ids["own_country_visit"]
    assert body["items"][0]["country_code"] == "PT"

    with Session(engine) as session:
        count = session.scalar(select(func.count()).select_from(TripCountryVisit))

    assert count == 1


def test_repeated_country_association_is_idempotent(
    associations_client,
) -> None:
    client, engine, ids = associations_client

    login_web(client)

    url = country_url(ids["own_trip"])

    payload = {
        "country_visit_id": ids["own_country_visit"],
    }

    first = client.post(
        url,
        json=payload,
        headers=ORIGIN,
    )

    second = client.post(
        url,
        json=payload,
        headers=ORIGIN,
    )

    assert first.status_code == 201
    assert second.status_code == 200

    with Session(engine) as session:
        count = session.scalar(select(func.count()).select_from(TripCountryVisit))

    assert count == 1


def test_country_association_can_be_removed(
    associations_client,
) -> None:
    client, engine, ids = associations_client

    login_web(client)

    url = country_url(ids["own_trip"])

    created = client.post(
        url,
        json={
            "country_visit_id": ids["own_country_visit"],
        },
        headers=ORIGIN,
    )

    assert created.status_code == 201

    deleted = client.delete(
        f"{url}/{ids['own_country_visit']}",
        headers=ORIGIN,
    )

    assert deleted.status_code == 204

    listed = client.get(url)

    assert listed.json()["total"] == 0

    with Session(engine) as session:
        visit = session.get(
            CountryVisit,
            UUID(ids["own_country_visit"]),
        )

    assert visit is not None


def test_removing_nonexistent_country_association_returns_404(
    associations_client,
) -> None:
    client, _, ids = associations_client

    login_web(client)

    response = client.delete(
        f"{country_url(ids['own_trip'])}/{ids['own_country_visit']}",
        headers=ORIGIN,
    )

    assert response.status_code == 404


# ---------------------------------------------------------
# City associations
# ---------------------------------------------------------


def test_city_visit_can_be_associated(
    associations_client,
) -> None:
    client, engine, ids = associations_client

    login_web(client)

    response = client.post(
        city_url(ids["own_trip"]),
        json={
            "city_visit_id": ids["own_city_visit"],
        },
        headers=ORIGIN,
    )

    assert response.status_code == 201, response.text

    listed = client.get(
        city_url(ids["own_trip"]),
    )

    assert listed.status_code == 200

    body = listed.json()

    assert body["total"] == 1

    visit = body["items"][0]

    assert visit["id"] == ids["own_city_visit"]
    assert visit["city_name"] == "Lisbon"
    assert visit["country_code"] == "PT"
    assert visit["country_name"] == "Portugal"

    # A city association must never create a country association.
    countries = client.get(
        country_url(ids["own_trip"]),
    )

    assert countries.json()["total"] == 0

    with Session(engine) as session:
        count = session.scalar(select(func.count()).select_from(TripCityVisit))

    assert count == 1


def test_repeated_city_association_is_idempotent(
    associations_client,
) -> None:
    client, engine, ids = associations_client

    login_web(client)

    url = city_url(ids["own_trip"])

    payload = {
        "city_visit_id": ids["own_city_visit"],
    }

    first = client.post(url, json=payload, headers=ORIGIN)
    second = client.post(url, json=payload, headers=ORIGIN)

    assert first.status_code == 201
    assert second.status_code == 200

    with Session(engine) as session:
        count = session.scalar(select(func.count()).select_from(TripCityVisit))

    assert count == 1


def test_city_association_can_be_removed(
    associations_client,
) -> None:
    client, engine, ids = associations_client

    login_web(client)

    url = city_url(ids["own_trip"])

    client.post(
        url,
        json={
            "city_visit_id": ids["own_city_visit"],
        },
        headers=ORIGIN,
    )

    deleted = client.delete(
        f"{url}/{ids['own_city_visit']}",
        headers=ORIGIN,
    )

    assert deleted.status_code == 204

    listed = client.get(url)

    assert listed.json()["total"] == 0

    with Session(engine) as session:
        visit = session.get(
            CityVisit,
            UUID(ids["own_city_visit"]),
        )

    assert visit is not None


# ---------------------------------------------------------
# Authorization
# ---------------------------------------------------------


@pytest.mark.parametrize(
    "kind,visit_key",
    [
        ("country-visits", "other_country_visit"),
        ("city-visits", "other_city_visit"),
    ],
)
def test_cannot_associate_another_users_visits(
    associations_client,
    kind: str,
    visit_key: str,
) -> None:
    client, engine, ids = associations_client

    login_web(client)

    payload_key = "country_visit_id" if kind == "country-visits" else "city_visit_id"

    response = client.post(
        f"{BASE_URL}/{ids['own_trip']}/{kind}",
        json={
            payload_key: ids[visit_key],
        },
        headers=ORIGIN,
    )

    assert response.status_code == 404

    with Session(engine) as session:
        country_count = session.scalar(select(func.count()).select_from(TripCountryVisit))

        city_count = session.scalar(select(func.count()).select_from(TripCityVisit))

    assert country_count == 0
    assert city_count == 0


@pytest.mark.parametrize(
    "kind,visit_key",
    [
        ("country-visits", "own_country_visit"),
        ("city-visits", "own_city_visit"),
    ],
)
def test_cannot_associate_visits_with_another_users_trip(
    associations_client,
    kind: str,
    visit_key: str,
) -> None:
    client, _, ids = associations_client

    login_web(client)

    payload_key = "country_visit_id" if kind == "country-visits" else "city_visit_id"

    response = client.post(
        f"{BASE_URL}/{ids['other_trip']}/{kind}",
        json={
            payload_key: ids[visit_key],
        },
        headers=ORIGIN,
    )

    assert response.status_code == 404


@pytest.mark.parametrize(
    "kind",
    [
        "country-visits",
        "city-visits",
    ],
)
def test_cannot_list_another_users_trip_associations(
    associations_client,
    kind: str,
) -> None:
    client, _, ids = associations_client

    login_web(client)

    response = client.get(
        f"{BASE_URL}/{ids['other_trip']}/{kind}",
    )

    assert response.status_code == 404


@pytest.mark.parametrize(
    "kind,visit_key",
    [
        ("country-visits", "other_country_visit"),
        ("city-visits", "other_city_visit"),
    ],
)
def test_cannot_remove_another_users_visits(
    associations_client,
    kind: str,
    visit_key: str,
) -> None:
    client, _, ids = associations_client

    login_web(client)

    response = client.delete(
        f"{BASE_URL}/{ids['own_trip']}/{kind}/{ids[visit_key]}",
        headers=ORIGIN,
    )

    assert response.status_code == 404


# ---------------------------------------------------------
# Referential integrity
# ---------------------------------------------------------


def test_deleting_trip_preserves_visits(
    associations_client,
) -> None:
    client, engine, ids = associations_client

    login_web(client)

    assert (
        client.post(
            country_url(ids["own_trip"]),
            json={"country_visit_id": ids["own_country_visit"]},
            headers=ORIGIN,
        ).status_code
        == 201
    )

    assert (
        client.post(
            city_url(ids["own_trip"]),
            json={"city_visit_id": ids["own_city_visit"]},
            headers=ORIGIN,
        ).status_code
        == 201
    )

    deleted = client.delete(
        f"{BASE_URL}/{ids['own_trip']}",
        headers=ORIGIN,
    )

    assert deleted.status_code == 204

    with Session(engine) as session:
        trip = session.get(Trip, UUID(ids["own_trip"]))

        country_visit = session.get(
            CountryVisit,
            UUID(ids["own_country_visit"]),
        )

        city_visit = session.get(
            CityVisit,
            UUID(ids["own_city_visit"]),
        )

        country_associations = session.scalar(select(func.count()).select_from(TripCountryVisit))

        city_associations = session.scalar(select(func.count()).select_from(TripCityVisit))

    assert trip is None
    assert country_visit is not None
    assert city_visit is not None

    assert country_associations == 0
    assert city_associations == 0


def test_deleting_country_visit_removes_association(
    associations_client,
) -> None:
    client, engine, ids = associations_client

    login_web(client)

    client.post(
        country_url(ids["own_trip"]),
        json={"country_visit_id": ids["own_country_visit"]},
        headers=ORIGIN,
    )

    response = client.delete(
        f"/api/v1/country-visits/{ids['own_country_visit']}",
        headers=ORIGIN,
    )

    assert response.status_code == 204

    with Session(engine) as session:
        count = session.scalar(select(func.count()).select_from(TripCountryVisit))

        trip = session.get(
            Trip,
            UUID(ids["own_trip"]),
        )

    assert count == 0
    assert trip is not None


def test_deleting_city_visit_removes_association(
    associations_client,
) -> None:
    client, engine, ids = associations_client

    login_web(client)

    client.post(
        city_url(ids["own_trip"]),
        json={"city_visit_id": ids["own_city_visit"]},
        headers=ORIGIN,
    )

    response = client.delete(
        f"/api/v1/city-visits/{ids['own_city_visit']}",
        headers=ORIGIN,
    )

    assert response.status_code == 204

    with Session(engine) as session:
        count = session.scalar(select(func.count()).select_from(TripCityVisit))

        trip = session.get(
            Trip,
            UUID(ids["own_trip"]),
        )

    assert count == 0
    assert trip is not None


# ---------------------------------------------------------
# Validation
# ---------------------------------------------------------


def test_invalid_association_payload_returns_422(
    associations_client,
) -> None:
    client, _, ids = associations_client

    login_web(client)

    response = client.post(
        country_url(ids["own_trip"]),
        json={
            "country_visit_id": "invalid-uuid",
        },
        headers=ORIGIN,
    )

    assert response.status_code == 422


def test_unknown_trip_returns_404(
    associations_client,
) -> None:
    client, _, _ = associations_client

    login_web(client)

    response = client.get(
        country_url(str(uuid4())),
    )

    assert response.status_code == 404


def test_country_visit_can_belong_to_multiple_trips(
    associations_client,
) -> None:
    """Removing one association must preserve other Trip links."""

    client, engine, ids = associations_client

    login_web(client)

    with Session(engine) as session:
        original_trip = session.get(
            Trip,
            UUID(ids["own_trip"]),
        )

        second_trip = Trip(
            user_id=original_trip.user_id,
            name="Europe 2025",
        )

        session.add(second_trip)
        session.commit()

        second_trip_id = str(second_trip.id)

    visit_id = ids["own_country_visit"]

    for trip_id in (ids["own_trip"], second_trip_id):
        response = client.post(
            country_url(trip_id),
            json={"country_visit_id": visit_id},
            headers=ORIGIN,
        )

        assert response.status_code == 201

    # Both Trips reference the same independent visit.
    with Session(engine) as session:
        associations = session.scalars(
            select(TripCountryVisit).where(TripCountryVisit.country_visit_id == UUID(visit_id))
        ).all()

        assert len(associations) == 2

    # Remove the association from only the first Trip.
    removed = client.delete(
        f"{country_url(ids['own_trip'])}/{visit_id}",
        headers=ORIGIN,
    )

    assert removed.status_code == 204

    first_list = client.get(country_url(ids["own_trip"]))
    second_list = client.get(country_url(second_trip_id))

    assert first_list.json()["total"] == 0
    assert second_list.json()["total"] == 1

    assert second_list.json()["items"][0]["id"] == visit_id

    # The original visit still exists.
    with Session(engine) as session:
        assert session.get(CountryVisit, UUID(visit_id)) is not None


def test_city_visit_can_belong_to_multiple_trips(
    associations_client,
) -> None:
    """A city visit remains available to every associated Trip."""

    client, engine, ids = associations_client

    login_web(client)

    with Session(engine) as session:
        original_trip = session.get(
            Trip,
            UUID(ids["own_trip"]),
        )

        second_trip = Trip(
            user_id=original_trip.user_id,
            name="Another Portugal Trip",
        )

        session.add(second_trip)
        session.commit()

        second_trip_id = str(second_trip.id)

    visit_id = ids["own_city_visit"]

    for trip_id in (ids["own_trip"], second_trip_id):
        response = client.post(
            city_url(trip_id),
            json={"city_visit_id": visit_id},
            headers=ORIGIN,
        )

        assert response.status_code == 201

    # Delete only the first Trip.
    deleted = client.delete(
        f"{BASE_URL}/{ids['own_trip']}",
        headers=ORIGIN,
    )

    assert deleted.status_code == 204

    # The second Trip must retain the association.
    remaining = client.get(city_url(second_trip_id))

    assert remaining.status_code == 200
    assert remaining.json()["total"] == 1

    assert remaining.json()["items"][0]["id"] == visit_id

    with Session(engine) as session:
        assert session.get(CityVisit, UUID(visit_id)) is not None

        associations = session.scalars(
            select(TripCityVisit).where(TripCityVisit.city_visit_id == UUID(visit_id))
        ).all()

        assert len(associations) == 1
        assert associations[0].trip_id == UUID(second_trip_id)


@pytest.mark.parametrize(
    "kind,visit_key",
    [
        ("country-visits", "own_country_visit"),
        ("city-visits", "own_city_visit"),
    ],
)
def test_cannot_remove_associations_from_another_users_trip(
    associations_client,
    kind: str,
    visit_key: str,
) -> None:
    """Users cannot modify associations of Trips they do not own."""

    client, _, ids = associations_client

    login_web(client)

    response = client.delete(
        f"{BASE_URL}/{ids['other_trip']}/{kind}/{ids[visit_key]}",
        headers=ORIGIN,
    )

    assert response.status_code == 404
