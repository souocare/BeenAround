"""Tests for personal flight domain rules and API schemas."""

from datetime import date, time

import pytest
from pydantic import ValidationError

from app.domain.flights import (
    CabinClass,
    FlightStatus,
    merge_flight_changes,
)
from app.schemas.flights import FlightCreate, FlightUpdate


def valid_flight(**overrides):
    payload = {
        "departure_airport_id": 100,
        "arrival_airport_id": 200,
        "departure_on": "2025-09-10",
        "status": "flown",
    }

    payload.update(overrides)

    return payload


def persisted_flight():
    """Represent the current state loaded from the database."""

    return {
        "departure_airport_id": 100,
        "arrival_airport_id": 200,
        "airline_id": 12,
        "airline_name": None,
        "departure_on": date(2025, 9, 10),
        "departure_time": time(22, 30),
        "arrival_on": date(2025, 9, 11),
        "arrival_time": time(6, 15),
        "status": FlightStatus.FLOWN,
    }


def test_create_minimal_flight():
    flight = FlightCreate.model_validate(valid_flight())

    assert flight.departure_airport_id == 100
    assert flight.arrival_airport_id == 200
    assert flight.departure_on == date(2025, 9, 10)
    assert flight.status == FlightStatus.FLOWN

    assert flight.airline_id is None
    assert flight.airline_name is None
    assert flight.departure_time is None


def test_status_is_required():
    payload = valid_flight()
    del payload["status"]

    with pytest.raises(ValidationError):
        FlightCreate.model_validate(payload)


@pytest.mark.parametrize(
    "field",
    [
        "departure_airport_id",
        "arrival_airport_id",
        "departure_on",
        "status",
    ],
)
def test_required_fields_cannot_be_null(field):
    with pytest.raises(ValidationError):
        FlightCreate.model_validate(valid_flight(**{field: None}))


def test_rejects_same_departure_and_arrival_airport():
    with pytest.raises(
        ValidationError,
        match="must be different",
    ):
        FlightCreate.model_validate(valid_flight(arrival_airport_id=100))


def test_rejects_invalid_airport_ids():
    with pytest.raises(ValidationError):
        FlightCreate.model_validate(valid_flight(departure_airport_id=-1))


def test_accepts_catalog_airline():
    flight = FlightCreate.model_validate(valid_flight(airline_id=12))

    assert flight.airline_id == 12
    assert flight.airline_name is None


def test_accepts_manual_airline():
    flight = FlightCreate.model_validate(valid_flight(airline_name="  Air   Berlin  "))

    assert flight.airline_id is None
    assert flight.airline_name == "Air Berlin"


def test_rejects_both_airline_options():
    with pytest.raises(
        ValidationError,
        match="not both",
    ):
        FlightCreate.model_validate(
            valid_flight(
                airline_id=12,
                airline_name="Air Berlin",
            )
        )


def test_normalizes_flight_number_and_registration():
    flight = FlightCreate.model_validate(
        valid_flight(
            flight_number="  tp1920  ",
            aircraft_registration="  cs-tva ",
            seat=" 12a ",
        )
    )

    assert flight.flight_number == "TP1920"
    assert flight.aircraft_registration == "CS-TVA"
    assert flight.seat == "12A"


def test_rejects_blank_optional_text():
    with pytest.raises(ValidationError):
        FlightCreate.model_validate(valid_flight(airline_name="   "))


def test_rejects_invalid_status():
    with pytest.raises(ValidationError):
        FlightCreate.model_validate(valid_flight(status="cancelled"))


def test_accepts_cabin_classes():
    for cabin_class in CabinClass:
        flight = FlightCreate.model_validate(valid_flight(cabin_class=cabin_class.value))

        assert flight.cabin_class == cabin_class


def test_rejects_invalid_cabin_class():
    with pytest.raises(ValidationError):
        FlightCreate.model_validate(valid_flight(cabin_class="private"))


def test_rejects_arrival_time_without_date():
    with pytest.raises(
        ValidationError,
        match="Arrival date is required",
    ):
        FlightCreate.model_validate(valid_flight(arrival_time="14:30"))


def test_accepts_arrival_date_without_time():
    flight = FlightCreate.model_validate(valid_flight(arrival_on="2025-09-11"))

    assert flight.arrival_on == date(2025, 9, 11)
    assert flight.arrival_time is None


def test_accepts_arrival_on_previous_local_date():
    """Crossing the date line may change the local calendar date."""

    flight = FlightCreate.model_validate(
        valid_flight(
            departure_on="2025-09-11",
            departure_time="23:30",
            arrival_on="2025-09-10",
            arrival_time="18:45",
        )
    )

    assert flight.arrival_on < flight.departure_on


@pytest.mark.parametrize(
    "field",
    [
        "departure_time",
        "arrival_time",
    ],
)
def test_rejects_timezone_aware_local_times(field):
    payload = valid_flight(arrival_on="2025-09-11")

    payload[field] = "12:30:00+01:00"

    with pytest.raises(
        ValidationError,
        match="without timezone offsets",
    ):
        FlightCreate.model_validate(payload)


def test_update_requires_at_least_one_field():
    with pytest.raises(
        ValidationError,
        match="At least one field",
    ):
        FlightUpdate.model_validate({})


@pytest.mark.parametrize(
    "field",
    [
        "departure_airport_id",
        "arrival_airport_id",
        "departure_on",
        "status",
    ],
)
def test_update_rejects_null_required_fields(field):
    with pytest.raises(ValidationError):
        FlightUpdate.model_validate({field: None})


def test_update_distinguishes_omitted_and_null():
    patch = FlightUpdate.model_validate({"airline_name": None})

    assert patch.model_fields_set == {"airline_name"}

    assert patch.model_dump(exclude_unset=True) == {
        "airline_name": None,
    }


def test_update_normalizes_text():
    patch = FlightUpdate.model_validate(
        {
            "flight_number": " tp1920 ",
            "seat": " 14c ",
        }
    )

    assert patch.model_dump(exclude_unset=True) == {
        "flight_number": "TP1920",
        "seat": "14C",
    }


def test_merge_updates_existing_flight():
    current = persisted_flight()

    merged = merge_flight_changes(
        current=current,
        changes={
            "flight_number": "TP1920",
        },
    )

    assert merged["flight_number"] == "TP1920"
    assert merged["airline_id"] == 12

    assert "flight_number" not in current


def test_merge_allows_switching_to_manual_airline():
    merged = merge_flight_changes(
        current=persisted_flight(),
        changes={
            "airline_id": None,
            "airline_name": "Air Berlin",
        },
    )

    assert merged["airline_id"] is None
    assert merged["airline_name"] == "Air Berlin"


def test_merge_rejects_ambiguous_airline():
    with pytest.raises(ValueError, match="not both"):
        merge_flight_changes(
            current=persisted_flight(),
            changes={
                "airline_name": "Air Berlin",
            },
        )


def test_merge_rejects_equal_airports():
    with pytest.raises(ValueError, match="must be different"):
        merge_flight_changes(
            current=persisted_flight(),
            changes={
                "arrival_airport_id": 100,
            },
        )


def test_merge_rejects_arrival_date_removal_with_time():
    with pytest.raises(
        ValueError,
        match="Arrival date is required",
    ):
        merge_flight_changes(
            current=persisted_flight(),
            changes={
                "arrival_on": None,
            },
        )


def test_merge_allows_clearing_arrival_details():
    merged = merge_flight_changes(
        current=persisted_flight(),
        changes={
            "arrival_on": None,
            "arrival_time": None,
        },
    )

    assert merged["arrival_on"] is None
    assert merged["arrival_time"] is None


def test_merge_does_not_mutate_inputs():
    current = persisted_flight()

    changes = {
        "airline_id": None,
        "airline_name": "Air Berlin",
    }

    original_current = current.copy()
    original_changes = changes.copy()

    merge_flight_changes(
        current=current,
        changes=changes,
    )

    assert current == original_current
    assert changes == original_changes
