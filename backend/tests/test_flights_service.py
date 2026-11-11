"""Tests for personal flight application services."""

from collections.abc import Generator
from datetime import date
from pathlib import Path
from uuid import UUID, uuid4

import pytest
from sqlalchemy import Engine, func, select
from sqlalchemy.orm import Session

from app.db.base import Base
from app.db.session import create_database_engine
from app.models.airline import Airline
from app.models.airport import Airport
from app.models.city import City  # noqa: F401
from app.models.city_visit import CityVisit
from app.models.country import Country  # noqa: F401
from app.models.country_visit import CountryVisit
from app.models.flight import Flight
from app.models.trip import Trip
from app.models.user import User
from app.schemas.flights import FlightCreate, FlightUpdate
from app.services.flights import (
    AirlineNotFound,
    AirportNotFound,
    FlightNotFound,
    InvalidFlightData,
    create_flight,
    delete_flight,
    get_flight,
    list_flights,
    update_flight,
)


@pytest.fixture
def flight_engine(tmp_path: Path) -> Generator[Engine, None, None]:
    engine = create_database_engine(f"sqlite:///{tmp_path / 'flights_service.db'}")

    Base.metadata.create_all(engine)

    with Session(engine) as session:
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
                    country_code=None,
                    latitude=38.77,
                    longitude=-9.13,
                    type="large_airport",
                    scheduled_service=True,
                ),
                Airport(
                    id=200,
                    ident="LPPR",
                    iata_code="OPO",
                    icao_code="LPPR",
                    name="Francisco de Sá Carneiro Airport",
                    municipality="Porto",
                    source_country_code="PT",
                    country_code=None,
                    latitude=41.24,
                    longitude=-8.68,
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
            ]
        )

        session.commit()

    yield engine

    engine.dispose()


def add_user(
    engine: Engine,
    *,
    user_id: UUID,
    username: str,
) -> None:
    with Session(engine) as session:
        session.add(
            User(
                id=user_id,
                username=username,
                email=f"{username}@example.com",
                display_name=username,
                password_hash="test-not-used-for-login",
            )
        )
        session.commit()


def flight_payload(**overrides) -> FlightCreate:
    values = {
        "departure_airport_id": 100,
        "arrival_airport_id": 200,
        "departure_on": "2025-09-10",
        "status": "flown",
    }

    values.update(overrides)

    return FlightCreate.model_validate(values)


def test_create_flight(flight_engine: Engine) -> None:
    user_id = uuid4()
    add_user(flight_engine, user_id=user_id, username="owner")

    flight = create_flight(
        engine=flight_engine,
        user_id=user_id,
        payload=flight_payload(
            airline_id=10,
            flight_number=" tp1920 ",
        ),
    )

    assert flight.id is not None
    assert flight.user_id == user_id
    assert flight.airline_id == 10
    assert flight.flight_number == "TP1920"


def test_create_rejects_unknown_departure_airport(
    flight_engine: Engine,
) -> None:
    user_id = uuid4()
    add_user(flight_engine, user_id=user_id, username="owner")

    with pytest.raises(AirportNotFound):
        create_flight(
            engine=flight_engine,
            user_id=user_id,
            payload=flight_payload(
                departure_airport_id=999999,
            ),
        )


def test_create_rejects_unknown_arrival_airport(
    flight_engine: Engine,
) -> None:
    user_id = uuid4()
    add_user(flight_engine, user_id=user_id, username="owner")

    with pytest.raises(AirportNotFound):
        create_flight(
            engine=flight_engine,
            user_id=user_id,
            payload=flight_payload(
                arrival_airport_id=999999,
            ),
        )


def test_create_rejects_unknown_airline(
    flight_engine: Engine,
) -> None:
    user_id = uuid4()
    add_user(flight_engine, user_id=user_id, username="owner")

    with pytest.raises(AirlineNotFound):
        create_flight(
            engine=flight_engine,
            user_id=user_id,
            payload=flight_payload(
                airline_id=999999,
            ),
        )


def test_create_allows_manual_airline(
    flight_engine: Engine,
) -> None:
    user_id = uuid4()
    add_user(flight_engine, user_id=user_id, username="owner")

    flight = create_flight(
        engine=flight_engine,
        user_id=user_id,
        payload=flight_payload(
            airline_name="Air Berlin",
        ),
    )

    assert flight.airline_id is None
    assert flight.airline_name == "Air Berlin"


def test_get_flight_enforces_ownership(
    flight_engine: Engine,
) -> None:
    owner_id = uuid4()
    other_id = uuid4()

    add_user(flight_engine, user_id=owner_id, username="owner")
    add_user(flight_engine, user_id=other_id, username="other")

    flight = create_flight(
        engine=flight_engine,
        user_id=owner_id,
        payload=flight_payload(),
    )

    owned = get_flight(
        engine=flight_engine,
        user_id=owner_id,
        flight_id=flight.id,
    )

    assert owned.id == flight.id

    with pytest.raises(FlightNotFound):
        get_flight(
            engine=flight_engine,
            user_id=other_id,
            flight_id=flight.id,
        )


def test_list_flights_is_private(
    flight_engine: Engine,
) -> None:
    owner_id = uuid4()
    other_id = uuid4()

    add_user(flight_engine, user_id=owner_id, username="owner")
    add_user(flight_engine, user_id=other_id, username="other")

    create_flight(
        engine=flight_engine,
        user_id=owner_id,
        payload=flight_payload(),
    )

    create_flight(
        engine=flight_engine,
        user_id=other_id,
        payload=flight_payload(),
    )

    flights, total = list_flights(
        engine=flight_engine,
        user_id=owner_id,
    )

    assert total == 1
    assert len(flights) == 1
    assert flights[0].user_id == owner_id


def test_list_flights_filters_by_status(
    flight_engine: Engine,
) -> None:
    user_id = uuid4()
    add_user(flight_engine, user_id=user_id, username="owner")

    create_flight(
        engine=flight_engine,
        user_id=user_id,
        payload=flight_payload(),
    )

    planned = create_flight(
        engine=flight_engine,
        user_id=user_id,
        payload=flight_payload(
            departure_on="2027-06-10",
            status="planned",
        ),
    )

    from app.domain.flights import FlightStatus

    flights, total = list_flights(
        engine=flight_engine,
        user_id=user_id,
        status=FlightStatus.PLANNED,
    )

    assert total == 1
    assert [flight.id for flight in flights] == [planned.id]


def test_update_flight(
    flight_engine: Engine,
) -> None:
    user_id = uuid4()
    add_user(flight_engine, user_id=user_id, username="owner")

    flight = create_flight(
        engine=flight_engine,
        user_id=user_id,
        payload=flight_payload(airline_id=10),
    )

    updated = update_flight(
        engine=flight_engine,
        user_id=user_id,
        flight_id=flight.id,
        payload=FlightUpdate.model_validate(
            {
                "airline_id": None,
                "airline_name": "Air Berlin",
                "seat": "12a",
            }
        ),
    )

    assert updated.airline_id is None
    assert updated.airline_name == "Air Berlin"
    assert updated.seat == "12A"


def test_update_rejects_invalid_final_state(
    flight_engine: Engine,
) -> None:
    user_id = uuid4()
    add_user(flight_engine, user_id=user_id, username="owner")

    flight = create_flight(
        engine=flight_engine,
        user_id=user_id,
        payload=flight_payload(airline_id=10),
    )

    with pytest.raises(InvalidFlightData):
        update_flight(
            engine=flight_engine,
            user_id=user_id,
            flight_id=flight.id,
            payload=FlightUpdate.model_validate({"airline_name": "Air Berlin"}),
        )

    persisted = get_flight(
        engine=flight_engine,
        user_id=user_id,
        flight_id=flight.id,
    )

    assert persisted.airline_id == 10
    assert persisted.airline_name is None


def test_update_rejects_unknown_airline(
    flight_engine: Engine,
) -> None:
    user_id = uuid4()
    add_user(flight_engine, user_id=user_id, username="owner")

    flight = create_flight(
        engine=flight_engine,
        user_id=user_id,
        payload=flight_payload(),
    )

    with pytest.raises(AirlineNotFound):
        update_flight(
            engine=flight_engine,
            user_id=user_id,
            flight_id=flight.id,
            payload=FlightUpdate.model_validate({"airline_id": 999999}),
        )


def test_update_enforces_ownership(
    flight_engine: Engine,
) -> None:
    owner_id = uuid4()
    other_id = uuid4()

    add_user(flight_engine, user_id=owner_id, username="owner")
    add_user(flight_engine, user_id=other_id, username="other")

    flight = create_flight(
        engine=flight_engine,
        user_id=owner_id,
        payload=flight_payload(),
    )

    with pytest.raises(FlightNotFound):
        update_flight(
            engine=flight_engine,
            user_id=other_id,
            flight_id=flight.id,
            payload=FlightUpdate.model_validate({"seat": "14A"}),
        )


def test_delete_enforces_ownership(
    flight_engine: Engine,
) -> None:
    owner_id = uuid4()
    other_id = uuid4()

    add_user(flight_engine, user_id=owner_id, username="owner")
    add_user(flight_engine, user_id=other_id, username="other")

    flight = create_flight(
        engine=flight_engine,
        user_id=owner_id,
        payload=flight_payload(),
    )

    with pytest.raises(FlightNotFound):
        delete_flight(
            engine=flight_engine,
            user_id=other_id,
            flight_id=flight.id,
        )

    delete_flight(
        engine=flight_engine,
        user_id=owner_id,
        flight_id=flight.id,
    )

    with pytest.raises(FlightNotFound):
        get_flight(
            engine=flight_engine,
            user_id=owner_id,
            flight_id=flight.id,
        )


def test_creating_flight_does_not_create_visits_or_trips(
    flight_engine: Engine,
) -> None:
    user_id = uuid4()
    add_user(flight_engine, user_id=user_id, username="owner")

    create_flight(
        engine=flight_engine,
        user_id=user_id,
        payload=flight_payload(),
    )

    with Session(flight_engine) as session:
        assert session.scalar(select(func.count()).select_from(CountryVisit)) == 0

        assert session.scalar(select(func.count()).select_from(CityVisit)) == 0

        assert session.scalar(select(func.count()).select_from(Trip)) == 0


def test_delete_flight_does_not_delete_catalog_data(
    flight_engine: Engine,
) -> None:
    user_id = uuid4()
    add_user(flight_engine, user_id=user_id, username="owner")

    flight = create_flight(
        engine=flight_engine,
        user_id=user_id,
        payload=flight_payload(airline_id=10),
    )

    delete_flight(
        engine=flight_engine,
        user_id=user_id,
        flight_id=flight.id,
    )

    with Session(flight_engine) as session:
        assert session.get(Airport, 100) is not None
        assert session.get(Airport, 200) is not None
        assert session.get(Airline, 10) is not None

        assert session.scalar(select(func.count()).select_from(Flight)) == 0
