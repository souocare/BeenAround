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


def resolve_partial_visit_update(
    *,
    current_started_on: date | None,
    current_started_on_precision: DatePrecision | None,
    current_ended_on: date | None,
    current_ended_on_precision: DatePrecision | None,
    changes: dict[str, date | DatePrecision | None],
) -> tuple[
    date | None,
    DatePrecision | None,
    date | None,
    DatePrecision | None,
]:
    """Resolve a partial visit update without inventing date information."""

    def resolve_date(
        *,
        field: str,
        current_date: date | None,
        current_precision: DatePrecision | None,
    ) -> tuple[date | None, DatePrecision | None]:
        precision_field = f"{field}_precision"

        date_provided = field in changes
        precision_provided = precision_field in changes

        if not date_provided and not precision_provided:
            return current_date, current_precision

        if date_provided:
            new_date = changes[field]

            if new_date is None:
                if precision_provided and changes[precision_field] is not None:
                    raise ValueError("Date precision requires a date.")

                return None, None

            if not isinstance(new_date, date):
                raise ValueError("Invalid date value.")

            if precision_provided:
                new_precision = changes[precision_field]
            else:
                new_precision = DatePrecision.DAY

            if new_precision is not None and not isinstance(
                new_precision,
                DatePrecision,
            ):
                raise ValueError("Invalid date precision.")

            normalized_date = normalize_partial_date(
                new_date,
                new_precision,
            )

            return normalized_date, new_precision

        new_precision = changes[precision_field]

        if new_precision is None:
            raise ValueError("Date precision cannot be cleared independently.")

        if not isinstance(new_precision, DatePrecision):
            raise ValueError("Invalid date precision.")

        if current_date is None or current_precision is None:
            raise ValueError("Date precision requires an existing date.")

        precision_rank = {
            DatePrecision.YEAR: 1,
            DatePrecision.MONTH: 2,
            DatePrecision.DAY: 3,
        }

        if precision_rank[new_precision] > precision_rank[current_precision]:
            raise ValueError("Increasing date precision requires a new date.")

        return (
            normalize_partial_date(current_date, new_precision),
            new_precision,
        )

    started_on, started_precision = resolve_date(
        field="started_on",
        current_date=current_started_on,
        current_precision=current_started_on_precision,
    )

    ended_on, ended_precision = resolve_date(
        field="ended_on",
        current_date=current_ended_on,
        current_precision=current_ended_on_precision,
    )

    normalized_start, normalized_end = validate_partial_visit_dates(
        started_on,
        started_precision,
        ended_on,
        ended_precision,
    )

    return (
        normalized_start,
        started_precision,
        normalized_end,
        ended_precision,
    )
