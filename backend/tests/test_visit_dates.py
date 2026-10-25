"""Tests for shared visit date precision rules."""

from datetime import date

import pytest

from app.domain.visit_dates import (
    DatePrecision,
    normalize_partial_date,
    partial_date_bounds,
    validate_partial_visit_dates,
    validate_visit_dates,
)


@pytest.mark.parametrize(
    ("value", "precision", "expected"),
    [
        (
            date(2024, 8, 15),
            DatePrecision.DAY,
            date(2024, 8, 15),
        ),
        (
            date(2024, 8, 15),
            DatePrecision.MONTH,
            date(2024, 8, 1),
        ),
        (
            date(2024, 8, 15),
            DatePrecision.YEAR,
            date(2024, 1, 1),
        ),
        (
            None,
            None,
            None,
        ),
    ],
)
def test_normalize_partial_date(value, precision, expected):
    assert normalize_partial_date(value, precision) == expected


@pytest.mark.parametrize(
    ("value", "precision"),
    [
        (None, DatePrecision.DAY),
        (None, DatePrecision.MONTH),
        (date(2024, 8, 15), None),
    ],
)
def test_normalize_partial_date_rejects_invalid_combinations(value, precision):
    with pytest.raises(ValueError):
        normalize_partial_date(value, precision)


@pytest.mark.parametrize(
    ("value", "precision", "expected"),
    [
        (
            date(2024, 8, 15),
            DatePrecision.DAY,
            (date(2024, 8, 15), date(2024, 8, 15)),
        ),
        (
            date(2024, 8, 1),
            DatePrecision.MONTH,
            (date(2024, 8, 1), date(2024, 8, 31)),
        ),
        (
            date(2024, 2, 1),
            DatePrecision.MONTH,
            (date(2024, 2, 1), date(2024, 2, 29)),
        ),
        (
            date(2024, 1, 1),
            DatePrecision.YEAR,
            (date(2024, 1, 1), date(2024, 12, 31)),
        ),
    ],
)
def test_partial_date_bounds(value, precision, expected):
    assert partial_date_bounds(value, precision) == expected


@pytest.mark.parametrize(
    (
        "started_on",
        "started_precision",
        "ended_on",
        "ended_precision",
    ),
    [
        (
            date(2024, 8, 1),
            DatePrecision.MONTH,
            date(2024, 8, 15),
            DatePrecision.DAY,
        ),
        (
            date(2024, 1, 1),
            DatePrecision.YEAR,
            date(2024, 8, 1),
            DatePrecision.MONTH,
        ),
        (
            date(2024, 8, 15),
            DatePrecision.DAY,
            date(2024, 8, 1),
            DatePrecision.MONTH,
        ),
        (
            None,
            None,
            None,
            None,
        ),
    ],
)
def test_validate_partial_visit_dates_accepts_possible_ranges(
    started_on,
    started_precision,
    ended_on,
    ended_precision,
):
    validate_partial_visit_dates(
        started_on,
        started_precision,
        ended_on,
        ended_precision,
    )


@pytest.mark.parametrize(
    (
        "started_on",
        "started_precision",
        "ended_on",
        "ended_precision",
    ),
    [
        (
            date(2024, 9, 1),
            DatePrecision.MONTH,
            date(2024, 8, 15),
            DatePrecision.DAY,
        ),
        (
            date(2025, 1, 1),
            DatePrecision.YEAR,
            date(2024, 12, 31),
            DatePrecision.DAY,
        ),
        (
            None,
            None,
            date(2024, 8, 15),
            DatePrecision.DAY,
        ),
    ],
)
def test_validate_partial_visit_dates_rejects_impossible_ranges(
    started_on,
    started_precision,
    ended_on,
    ended_precision,
):
    with pytest.raises(ValueError):
        validate_partial_visit_dates(
            started_on,
            started_precision,
            ended_on,
            ended_precision,
        )


def test_existing_exact_date_validation_remains_compatible():
    validate_visit_dates(
        date(2024, 8, 10),
        date(2024, 8, 15),
    )

    with pytest.raises(ValueError):
        validate_visit_dates(
            date(2024, 8, 15),
            date(2024, 8, 10),
        )
