"""Tests for shared visit date precision rules."""

from datetime import date

import pytest

from app.domain.visit_dates import (
    DatePrecision,
    normalize_partial_date,
    partial_date_bounds,
    resolve_partial_visit_update,
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


def test_partial_update_preserves_omitted_dates():
    result = resolve_partial_visit_update(
        current_started_on=date(2024, 8, 1),
        current_started_on_precision=DatePrecision.MONTH,
        current_ended_on=date(2024, 8, 31),
        current_ended_on_precision=DatePrecision.DAY,
        changes={},
    )

    assert result == (
        date(2024, 8, 1),
        DatePrecision.MONTH,
        date(2024, 8, 31),
        DatePrecision.DAY,
    )


def test_partial_update_new_date_defaults_to_day():
    result = resolve_partial_visit_update(
        current_started_on=date(2024, 8, 1),
        current_started_on_precision=DatePrecision.MONTH,
        current_ended_on=date(2024, 9, 30),
        current_ended_on_precision=DatePrecision.DAY,
        changes={
            "started_on": date(2024, 9, 15),
        },
    )

    assert result == (
        date(2024, 9, 15),
        DatePrecision.DAY,
        date(2024, 9, 30),
        DatePrecision.DAY,
    )


def test_partial_update_normalizes_explicit_precision():
    result = resolve_partial_visit_update(
        current_started_on=date(2024, 8, 10),
        current_started_on_precision=DatePrecision.DAY,
        current_ended_on=date(2024, 8, 31),
        current_ended_on_precision=DatePrecision.DAY,
        changes={
            "started_on": date(2024, 8, 15),
            "started_on_precision": DatePrecision.MONTH,
        },
    )

    assert result == (
        date(2024, 8, 1),
        DatePrecision.MONTH,
        date(2024, 8, 31),
        DatePrecision.DAY,
    )


@pytest.mark.parametrize(
    ("current_precision", "new_precision", "expected_date"),
    [
        (
            DatePrecision.DAY,
            DatePrecision.MONTH,
            date(2024, 8, 1),
        ),
        (
            DatePrecision.DAY,
            DatePrecision.YEAR,
            date(2024, 1, 1),
        ),
        (
            DatePrecision.MONTH,
            DatePrecision.YEAR,
            date(2024, 1, 1),
        ),
    ],
)
def test_partial_update_allows_reducing_precision(
    current_precision,
    new_precision,
    expected_date,
):
    result = resolve_partial_visit_update(
        current_started_on=date(2024, 8, 15)
        if current_precision == DatePrecision.DAY
        else date(2024, 8, 1),
        current_started_on_precision=current_precision,
        current_ended_on=date(2024, 12, 31),
        current_ended_on_precision=DatePrecision.DAY,
        changes={
            "started_on_precision": new_precision,
        },
    )

    assert result[0] == expected_date
    assert result[1] == new_precision


@pytest.mark.parametrize(
    ("current_precision", "new_precision"),
    [
        (DatePrecision.YEAR, DatePrecision.MONTH),
        (DatePrecision.YEAR, DatePrecision.DAY),
        (DatePrecision.MONTH, DatePrecision.DAY),
    ],
)
def test_partial_update_rejects_increasing_precision_without_date(
    current_precision,
    new_precision,
):
    with pytest.raises(
        ValueError,
        match="Increasing date precision requires a new date",
    ):
        resolve_partial_visit_update(
            current_started_on=date(2024, 1, 1),
            current_started_on_precision=current_precision,
            current_ended_on=None,
            current_ended_on_precision=None,
            changes={
                "started_on_precision": new_precision,
            },
        )


def test_partial_update_rejects_precision_without_existing_date():
    with pytest.raises(ValueError):
        resolve_partial_visit_update(
            current_started_on=None,
            current_started_on_precision=None,
            current_ended_on=None,
            current_ended_on_precision=None,
            changes={
                "started_on_precision": DatePrecision.MONTH,
            },
        )


def test_partial_update_rejects_null_precision_with_existing_date():
    with pytest.raises(ValueError):
        resolve_partial_visit_update(
            current_started_on=date(2024, 8, 15),
            current_started_on_precision=DatePrecision.DAY,
            current_ended_on=None,
            current_ended_on_precision=None,
            changes={
                "started_on_precision": None,
            },
        )


def test_partial_update_rejects_invalid_final_range():
    with pytest.raises(
        ValueError,
        match="End date cannot be earlier than start date",
    ):
        resolve_partial_visit_update(
            current_started_on=date(2024, 8, 1),
            current_started_on_precision=DatePrecision.MONTH,
            current_ended_on=date(2024, 8, 31),
            current_ended_on_precision=DatePrecision.DAY,
            changes={
                "started_on": date(2024, 9, 15),
            },
        )


def test_partial_update_rejects_end_without_start():
    with pytest.raises(
        ValueError,
        match="Start date is required",
    ):
        resolve_partial_visit_update(
            current_started_on=date(2024, 8, 15),
            current_started_on_precision=DatePrecision.DAY,
            current_ended_on=date(2024, 8, 20),
            current_ended_on_precision=DatePrecision.DAY,
            changes={
                "started_on": None,
            },
        )


@pytest.mark.parametrize(
    ("started_on", "started_precision", "ended_on", "ended_precision", "message"),
    [
        (None, None, None, None, "Start date is required."),
        (
            None,
            None,
            date(2024, 8, 15),
            DatePrecision.DAY,
            "Start date is required.",
        ),
        (
            date(2024, 8, 15),
            DatePrecision.DAY,
            None,
            None,
            "End date is required.",
        ),
    ],
)
def test_validate_partial_visit_dates_requires_complete_range(
    started_on,
    started_precision,
    ended_on,
    ended_precision,
    message,
):
    with pytest.raises(ValueError, match=message):
        validate_partial_visit_dates(
            started_on,
            started_precision,
            ended_on,
            ended_precision,
        )
