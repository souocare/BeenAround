"""Tests for geographic airport timezone resolution."""

import pytest

from app.services.airport_timezones import AirportTimezoneResolver


@pytest.fixture(scope="module")
def resolver() -> AirportTimezoneResolver:
    return AirportTimezoneResolver()


@pytest.mark.parametrize(
    ("latitude", "longitude", "expected"),
    [
        (38.7742, -9.1342, "Europe/Lisbon"),
        (41.2974, 2.0833, "Europe/Madrid"),
        (37.7412, -25.6979, "Atlantic/Azores"),
        (40.6413, -73.7781, "America/New_York"),
        (33.9416, -118.4085, "America/Los_Angeles"),
        (35.5494, 139.7798, "Asia/Tokyo"),
        (28.5562, 77.1000, "Asia/Kolkata"),
    ],
)
def test_resolves_airport_timezones(
    resolver,
    latitude,
    longitude,
    expected,
):
    assert (
        resolver.resolve(
            latitude=latitude,
            longitude=longitude,
        )
        == expected
    )


@pytest.mark.parametrize(
    ("latitude", "longitude"),
    [
        (None, None),
        (None, -9.1342),
        (38.7742, None),
    ],
)
def test_returns_none_when_coordinates_are_missing(
    resolver,
    latitude,
    longitude,
):
    assert (
        resolver.resolve(
            latitude=latitude,
            longitude=longitude,
        )
        is None
    )
