"""Tests for optional Trip date validation."""

from datetime import date

import pytest

from app.domain.trip_dates import validate_trip_dates
from app.domain.visit_dates import DatePrecision


def test_trip_without_dates() -> None:
    result = validate_trip_dates(
        None,
        None,
        None,
        None,
    )

    assert result == (None, None)


def test_trip_with_only_start_date() -> None:
    result = validate_trip_dates(
        date(2027, 4, 10),
        DatePrecision.DAY,
        None,
        None,
    )

    assert result == (
        date(2027, 4, 10),
        None,
    )


def test_trip_with_only_end_date() -> None:
    result = validate_trip_dates(
        None,
        None,
        date(2027, 4, 20),
        DatePrecision.DAY,
    )

    assert result == (
        None,
        date(2027, 4, 20),
    )


def test_trip_with_valid_date_range() -> None:
    result = validate_trip_dates(
        date(2027, 4, 10),
        DatePrecision.DAY,
        date(2027, 4, 20),
        DatePrecision.DAY,
    )

    assert result == (
        date(2027, 4, 10),
        date(2027, 4, 20),
    )


def test_trip_with_invalid_date_range() -> None:
    with pytest.raises(
        ValueError,
        match="Trip end date cannot be earlier",
    ):
        validate_trip_dates(
            date(2027, 4, 20),
            DatePrecision.DAY,
            date(2027, 4, 10),
            DatePrecision.DAY,
        )


def test_trip_with_month_precision() -> None:
    result = validate_trip_dates(
        date(2027, 4, 15),
        DatePrecision.MONTH,
        date(2027, 5, 20),
        DatePrecision.MONTH,
    )

    assert result == (
        date(2027, 4, 1),
        date(2027, 5, 1),
    )


def test_trip_with_year_precision() -> None:
    result = validate_trip_dates(
        date(2027, 8, 15),
        DatePrecision.YEAR,
        date(2028, 6, 20),
        DatePrecision.YEAR,
    )

    assert result == (
        date(2027, 1, 1),
        date(2028, 1, 1),
    )


def test_trip_with_overlapping_partial_dates() -> None:
    """An exact start within the end month is valid."""

    result = validate_trip_dates(
        date(2027, 4, 20),
        DatePrecision.DAY,
        date(2027, 4, 1),
        DatePrecision.MONTH,
    )

    assert result == (
        date(2027, 4, 20),
        date(2027, 4, 1),
    )


@pytest.mark.parametrize(
    "started_on,started_precision,ended_on,ended_precision",
    [
        (
            None,
            DatePrecision.DAY,
            None,
            None,
        ),
        (
            None,
            None,
            None,
            DatePrecision.MONTH,
        ),
        (
            date(2027, 4, 10),
            None,
            None,
            None,
        ),
        (
            None,
            None,
            date(2027, 4, 20),
            None,
        ),
    ],
)
def test_trip_rejects_inconsistent_date_precision(
    started_on: date | None,
    started_precision: DatePrecision | None,
    ended_on: date | None,
    ended_precision: DatePrecision | None,
) -> None:
    with pytest.raises(ValueError):
        validate_trip_dates(
            started_on,
            started_precision,
            ended_on,
            ended_precision,
        )