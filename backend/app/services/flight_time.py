"""Timezone-aware calculations for flight schedules.

Flight dates and times are stored as airport-local wall times.

This module resolves those values using IANA timezone rules.
Ambiguous or nonexistent local times are never silently guessed.
"""

from dataclasses import dataclass
from datetime import date, datetime, time, timezone
from enum import StrEnum
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


class LocalTimeStatus(StrEnum):
    VALID = "valid"
    AMBIGUOUS = "ambiguous"
    NONEXISTENT = "nonexistent"
    UNAVAILABLE = "unavailable"


@dataclass(frozen=True)
class ResolvedLocalTime:
    status: LocalTimeStatus
    utc_datetime: datetime | None = None
    utc_offset_minutes: int | None = None


@dataclass(frozen=True)
class FlightTiming:
    departure: ResolvedLocalTime
    arrival: ResolvedLocalTime
    duration_minutes: int | None


def resolve_local_time(
    *,
    date_value: str | None,
    time_value: str | None,
    timezone_id: str | None,
) -> ResolvedLocalTime:
    """Resolve an airport-local wall time to a unique UTC instant.

    Returns UNAVAILABLE when required data is missing or invalid.

    Detects DST transitions using both PEP 495 fold interpretations.
    """

    unavailable = ResolvedLocalTime(
        status=LocalTimeStatus.UNAVAILABLE,
    )

    if not date_value or not time_value or not timezone_id:
        return unavailable

    try:
        local_date = date.fromisoformat(date_value)
        local_time = time.fromisoformat(time_value)

        if local_time.tzinfo is not None:
            return unavailable

        location = ZoneInfo(timezone_id)
    except (ValueError, ZoneInfoNotFoundError):
        return unavailable

    naive_local = datetime.combine(
        local_date,
        local_time,
    )

    valid_candidates: dict[datetime, datetime] = {}

    for fold in (0, 1):
        candidate = naive_local.replace(
            tzinfo=location,
            fold=fold,
        )

        utc_candidate = candidate.astimezone(timezone.utc)

        roundtrip = utc_candidate.astimezone(location)

        # A nonexistent local time cannot survive a
        # UTC -> local roundtrip unchanged.
        if roundtrip.replace(tzinfo=None) != naive_local:
            continue

        valid_candidates[utc_candidate] = candidate

    if not valid_candidates:
        return ResolvedLocalTime(
            status=LocalTimeStatus.NONEXISTENT,
        )

    if len(valid_candidates) > 1:
        return ResolvedLocalTime(
            status=LocalTimeStatus.AMBIGUOUS,
        )

    utc_datetime, local_datetime = next(iter(valid_candidates.items()))

    offset = local_datetime.utcoffset()

    if offset is None:
        return unavailable

    return ResolvedLocalTime(
        status=LocalTimeStatus.VALID,
        utc_datetime=utc_datetime,
        utc_offset_minutes=int(offset.total_seconds() // 60),
    )


def calculate_flight_timing(
    *,
    departure_on: str,
    departure_time: str | None,
    departure_timezone_id: str | None,
    arrival_on: str | None,
    arrival_time: str | None,
    arrival_timezone_id: str | None,
) -> FlightTiming:
    """Calculate elapsed flight duration using UTC instants."""

    departure = resolve_local_time(
        date_value=departure_on,
        time_value=departure_time,
        timezone_id=departure_timezone_id,
    )

    arrival = resolve_local_time(
        date_value=arrival_on,
        time_value=arrival_time,
        timezone_id=arrival_timezone_id,
    )

    duration_minutes = None

    if (
        departure.status == LocalTimeStatus.VALID
        and arrival.status == LocalTimeStatus.VALID
        and departure.utc_datetime is not None
        and arrival.utc_datetime is not None
    ):
        elapsed = (arrival.utc_datetime - departure.utc_datetime).total_seconds()

        # A negative elapsed duration indicates inconsistent
        # schedule data. Never report it as a real duration.
        if elapsed >= 0:
            duration_minutes = round(elapsed / 60)

    return FlightTiming(
        departure=departure,
        arrival=arrival,
        duration_minutes=duration_minutes,
    )
