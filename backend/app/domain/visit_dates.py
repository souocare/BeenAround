"""Shared date validation and temporal precision rules for travel visits."""

from calendar import monthrange
from datetime import date
from enum import StrEnum


class DatePrecision(StrEnum):
    """Supported precision levels for visit dates."""

    DAY = "day"
    MONTH = "month"
    YEAR = "year"


def normalize_partial_date(
    value: date | None,
    precision: DatePrecision | None,
) -> date | None:
    """Normalize a partial date to its canonical internal representation.

    The stored date is a technical representation. Its precision determines
    which components are actually known.
    """

    if value is None:
        if precision is not None:
            raise ValueError("Date precision requires a date.")
        return None

    if precision is None:
        raise ValueError("A date requires a precision.")

    if precision == DatePrecision.DAY:
        return value

    if precision == DatePrecision.MONTH:
        return date(value.year, value.month, 1)

    return date(value.year, 1, 1)


def partial_date_bounds(
    value: date,
    precision: DatePrecision,
) -> tuple[date, date]:
    """Return the earliest and latest possible dates for a partial date."""

    if precision == DatePrecision.DAY:
        return value, value

    if precision == DatePrecision.MONTH:
        last_day = monthrange(value.year, value.month)[1]

        return (
            date(value.year, value.month, 1),
            date(value.year, value.month, last_day),
        )

    return (
        date(value.year, 1, 1),
        date(value.year, 12, 31),
    )


def validate_partial_visit_dates(
    started_on: date | None,
    started_on_precision: DatePrecision | None,
    ended_on: date | None,
    ended_on_precision: DatePrecision | None,
) -> tuple[date | None, date | None]:
    """Validate and normalize a visit's temporal range."""

    normalized_start = normalize_partial_date(
        started_on,
        started_on_precision,
    )

    normalized_end = normalize_partial_date(
        ended_on,
        ended_on_precision,
    )

    if normalized_end is None:
        return normalized_start, None

    if normalized_start is None:
        raise ValueError("End date requires a start date.")

    assert started_on_precision is not None
    assert ended_on_precision is not None

    earliest_start, _ = partial_date_bounds(
        normalized_start,
        started_on_precision,
    )

    _, latest_end = partial_date_bounds(
        normalized_end,
        ended_on_precision,
    )

    if earliest_start > latest_end:
        raise ValueError("End date cannot be earlier than start date.")

    return normalized_start, normalized_end


def validate_visit_dates(
    started_on: date | None,
    ended_on: date | None,
) -> None:
    """Validate the date range of a visit using exact dates.

    Retained for compatibility with existing callers.
    """

    if ended_on is None:
        return

    if started_on is None:
        raise ValueError("End date requires a start date.")

    if ended_on < started_on:
        raise ValueError("End date cannot be earlier than start date.")
