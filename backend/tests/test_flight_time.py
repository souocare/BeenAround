"""Tests for timezone-aware flight schedule calculations."""

from datetime import datetime, timezone

from app.services.flight_time import (
    LocalTimeStatus,
    calculate_flight_timing,
    resolve_local_time,
)


def test_lisbon_to_barcelona_in_summer():
    timing = calculate_flight_timing(
        departure_on="2026-10-10",
        departure_time="19:20",
        departure_timezone_id="Europe/Lisbon",
        arrival_on="2026-10-10",
        arrival_time="22:15",
        arrival_timezone_id="Europe/Madrid",
    )

    assert timing.departure.status == LocalTimeStatus.VALID
    assert timing.arrival.status == LocalTimeStatus.VALID

    assert timing.departure.utc_offset_minutes == 60
    assert timing.arrival.utc_offset_minutes == 120

    assert timing.duration_minutes == 115

    assert timing.departure.utc_datetime == datetime(2026, 10, 10, 18, 20, tzinfo=timezone.utc)

    assert timing.arrival.utc_datetime == datetime(2026, 10, 10, 20, 15, tzinfo=timezone.utc)


def test_winter_offsets():
    departure = resolve_local_time(
        date_value="2026-12-10",
        time_value="19:20",
        timezone_id="Europe/Lisbon",
    )

    arrival = resolve_local_time(
        date_value="2026-12-10",
        time_value="22:15",
        timezone_id="Europe/Madrid",
    )

    assert departure.utc_offset_minutes == 0
    assert arrival.utc_offset_minutes == 60


def test_timezone_without_dst():
    result = resolve_local_time(
        date_value="2026-07-10",
        time_value="12:00",
        timezone_id="Asia/Kolkata",
    )

    assert result.status == LocalTimeStatus.VALID
    assert result.utc_offset_minutes == 330


def test_crosses_midnight():
    timing = calculate_flight_timing(
        departure_on="2026-08-10",
        departure_time="23:30",
        departure_timezone_id="Europe/Lisbon",
        arrival_on="2026-08-11",
        arrival_time="02:00",
        arrival_timezone_id="Europe/Lisbon",
    )

    assert timing.duration_minutes == 150


def test_detects_ambiguous_local_time():
    result = resolve_local_time(
        date_value="2026-10-25",
        time_value="01:30",
        timezone_id="Europe/Lisbon",
    )

    assert result.status == LocalTimeStatus.AMBIGUOUS
    assert result.utc_datetime is None


def test_detects_nonexistent_local_time():
    result = resolve_local_time(
        date_value="2026-03-29",
        time_value="01:30",
        timezone_id="Europe/Lisbon",
    )

    assert result.status == LocalTimeStatus.NONEXISTENT
    assert result.utc_datetime is None


def test_ambiguous_departure_prevents_duration():
    timing = calculate_flight_timing(
        departure_on="2026-10-25",
        departure_time="01:30",
        departure_timezone_id="Europe/Lisbon",
        arrival_on="2026-10-25",
        arrival_time="05:00",
        arrival_timezone_id="Europe/Madrid",
    )

    assert timing.departure.status == LocalTimeStatus.AMBIGUOUS
    assert timing.duration_minutes is None


def test_missing_timezone_prevents_duration():
    timing = calculate_flight_timing(
        departure_on="2026-10-10",
        departure_time="19:20",
        departure_timezone_id=None,
        arrival_on="2026-10-10",
        arrival_time="22:15",
        arrival_timezone_id="Europe/Madrid",
    )

    assert timing.departure.status == LocalTimeStatus.UNAVAILABLE
    assert timing.duration_minutes is None


def test_invalid_timezone_is_unavailable():
    result = resolve_local_time(
        date_value="2026-10-10",
        time_value="19:20",
        timezone_id="Invalid/Timezone",
    )

    assert result.status == LocalTimeStatus.UNAVAILABLE


def test_negative_duration_is_not_reported():
    timing = calculate_flight_timing(
        departure_on="2026-10-10",
        departure_time="20:00",
        departure_timezone_id="Europe/Lisbon",
        arrival_on="2026-10-10",
        arrival_time="18:00",
        arrival_timezone_id="Europe/Lisbon",
    )

    assert timing.duration_minutes is None


def test_historical_dst_rules():
    summer = resolve_local_time(
        date_value="2015-07-10",
        time_value="12:00",
        timezone_id="Europe/Lisbon",
    )

    winter = resolve_local_time(
        date_value="2015-12-10",
        time_value="12:00",
        timezone_id="Europe/Lisbon",
    )

    assert summer.utc_offset_minutes == 60
    assert winter.utc_offset_minutes == 0
