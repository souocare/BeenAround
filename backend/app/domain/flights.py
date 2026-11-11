"""Domain rules for personal flight records."""

from datetime import date, time
from enum import Enum
from typing import Any


class FlightStatus(str, Enum):
    """Explicit lifecycle status of a personal flight."""

    FLOWN = "flown"
    PLANNED = "planned"


class CabinClass(str, Enum):
    """Supported passenger cabin classes."""

    ECONOMY = "economy"
    PREMIUM_ECONOMY = "premium_economy"
    BUSINESS = "business"
    FIRST = "first"


REQUIRED_FLIGHT_FIELDS = frozenset(
    {
        "departure_airport_id",
        "arrival_airport_id",
        "departure_on",
        "status",
    }
)


def normalize_optional_text(
    value: str | None,
    *,
    max_length: int,
    uppercase: bool = False,
) -> str | None:
    """Normalize optional text without silently accepting blank values."""

    if value is None:
        return None

    normalized = " ".join(value.split())

    if not normalized:
        raise ValueError("Text cannot be blank.")

    if uppercase:
        normalized = normalized.upper()

    if len(normalized) > max_length:
        raise ValueError(f"Text cannot exceed {max_length} characters.")

    return normalized


def validate_local_time(
    value: time | None,
) -> time | None:
    """Require a timezone-naive local wall-clock time."""

    if value is not None and value.tzinfo is not None:
        raise ValueError("Flight times must be local times without timezone offsets.")

    return value


def validate_flight_consistency(
    *,
    departure_airport_id: int,
    arrival_airport_id: int,
    airline_id: int | None,
    airline_name: str | None,
    departure_on: date,
    departure_time: time | None,
    arrival_on: date | None,
    arrival_time: time | None,
    status: FlightStatus,
) -> None:
    """Validate the complete logical state of a flight.

    This function is shared by creation and update workflows.
    It deliberately does not compare departure and arrival local
    dates because flights may cross the international date line.
    """

    if departure_airport_id <= 0:
        raise ValueError("Departure airport ID must be positive.")

    if arrival_airport_id <= 0:
        raise ValueError("Arrival airport ID must be positive.")

    if departure_airport_id == arrival_airport_id:
        raise ValueError("Departure and arrival airports must be different.")

    if airline_id is not None and airline_id <= 0:
        raise ValueError("Airline ID must be positive.")

    if airline_id is not None and airline_name is not None:
        raise ValueError(
            "Select an airline from the catalog or enter a manual airline name, not both."
        )

    if arrival_time is not None and arrival_on is None:
        raise ValueError("Arrival date is required when arrival time is provided.")

    validate_local_time(departure_time)
    validate_local_time(arrival_time)

    # Explicitly consume these required values as part of the contract.
    # Pydantic validates their concrete types and permitted enum values.
    if departure_on is None:
        raise ValueError("Departure date is required.")

    if status not in FlightStatus:
        raise ValueError("Invalid flight status.")


def merge_flight_changes(
    *,
    current: dict[str, Any],
    changes: dict[str, Any],
) -> dict[str, Any]:
    """Resolve a partial update into a complete validated flight state.

    The caller supplies the current persisted values and only the fields
    explicitly sent by the client.

    This function does not modify either input dictionary.
    """

    for field in REQUIRED_FLIGHT_FIELDS:
        if field in changes and changes[field] is None:
            raise ValueError(f"{field} cannot be null.")

    merged = {**current, **changes}

    validate_flight_consistency(
        departure_airport_id=merged["departure_airport_id"],
        arrival_airport_id=merged["arrival_airport_id"],
        airline_id=merged["airline_id"],
        airline_name=merged["airline_name"],
        departure_on=merged["departure_on"],
        departure_time=merged["departure_time"],
        arrival_on=merged["arrival_on"],
        arrival_time=merged["arrival_time"],
        status=merged["status"],
    )

    return merged
