"""Domain rules for optional Trip date ranges."""

from datetime import date

from app.domain.visit_dates import (
    DatePrecision,
    normalize_partial_date,
    partial_date_bounds,
)
from app.domain.visit_dates import DatePrecision, normalize_partial_date


def validate_trip_dates(
    started_on: date | None,
    started_on_precision: DatePrecision | None,
    ended_on: date | None,
    ended_on_precision: DatePrecision | None,
) -> tuple[date | None, date | None]:
    """Validate and normalize an optional Trip date range.

    Unlike visits, Trips may have:
    - No dates.
    - Only a start date.
    - Only an end date.
    - Both dates.

    Partial dates retain their declared precision.
    """

    normalized_start = normalize_partial_date(
        started_on,
        started_on_precision,
    )

    normalized_end = normalize_partial_date(
        ended_on,
        ended_on_precision,
    )

    if normalized_start is None or normalized_end is None:
        return normalized_start, normalized_end

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
        raise ValueError("Trip end date cannot be earlier than start date.")

    return normalized_start, normalized_end


def resolve_trip_date_update(
    *,
    current_started_on: date | None,
    current_started_on_precision: DatePrecision | None,
    current_ended_on: date | None,
    current_ended_on_precision: DatePrecision | None,
    changes: dict,
) -> tuple[
    date | None,
    DatePrecision | None,
    date | None,
    DatePrecision | None,
]:
    """Resolve partial Trip date updates without inventing information."""

    precision_rank = {
        DatePrecision.YEAR: 1,
        DatePrecision.MONTH: 2,
        DatePrecision.DAY: 3,
    }

    def resolve_boundary(
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

            new_precision = changes[precision_field] if precision_provided else DatePrecision.DAY

            normalized = normalize_partial_date(
                new_date,
                new_precision,
            )

            return normalized, new_precision

        new_precision = changes[precision_field]

        if new_precision is None:
            raise ValueError("Date precision cannot be cleared independently.")

        if current_date is None or current_precision is None:
            raise ValueError("Date precision requires an existing date.")

        if precision_rank[new_precision] > precision_rank[current_precision]:
            raise ValueError("Increasing date precision requires a new date.")

        return (
            normalize_partial_date(current_date, new_precision),
            new_precision,
        )

    started_on, started_precision = resolve_boundary(
        field="started_on",
        current_date=current_started_on,
        current_precision=current_started_on_precision,
    )

    ended_on, ended_precision = resolve_boundary(
        field="ended_on",
        current_date=current_ended_on,
        current_precision=current_ended_on_precision,
    )

    normalized_start, normalized_end = validate_trip_dates(
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
