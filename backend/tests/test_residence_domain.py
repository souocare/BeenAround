"""Tests for historical residence domain rules."""

from datetime import date

import pytest

from app.domain.residences import (
    ResidenceOverlapKind,
    ResidencePeriod,
    classify_residence_overlap,
    validate_residence_dates,
    validate_residence_destination,
)
from app.domain.visit_dates import DatePrecision


def period(
    start: date,
    end: date,
    *,
    start_precision: DatePrecision = DatePrecision.MONTH,
    end_precision: DatePrecision = DatePrecision.MONTH,
) -> ResidencePeriod:
    """Create a validated residence period for tests."""

    return ResidencePeriod(
        started_on=start,
        started_on_precision=start_precision,
        ended_on=end,
        ended_on_precision=end_precision,
    )


def test_residence_accepts_month_precision() -> None:
    start, end = validate_residence_dates(
        started_on=date(2020, 1, 1),
        started_on_precision=DatePrecision.MONTH,
        ended_on=date(2023, 12, 1),
        ended_on_precision=DatePrecision.MONTH,
    )

    assert start == date(2020, 1, 1)
    assert end == date(2023, 12, 1)


def test_residence_accepts_day_precision() -> None:
    start, end = validate_residence_dates(
        started_on=date(2020, 1, 15),
        started_on_precision=DatePrecision.DAY,
        ended_on=date(2023, 12, 20),
        ended_on_precision=DatePrecision.DAY,
    )

    assert start == date(2020, 1, 15)
    assert end == date(2023, 12, 20)


def test_residence_normalizes_month_dates() -> None:
    start, end = validate_residence_dates(
        started_on=date(2020, 1, 15),
        started_on_precision=DatePrecision.MONTH,
        ended_on=date(2023, 12, 20),
        ended_on_precision=DatePrecision.MONTH,
    )

    assert start == date(2020, 1, 1)
    assert end == date(2023, 12, 1)


@pytest.mark.parametrize(
    ("start_precision", "end_precision"),
    [
        (DatePrecision.YEAR, DatePrecision.MONTH),
        (DatePrecision.MONTH, DatePrecision.YEAR),
        (DatePrecision.YEAR, DatePrecision.YEAR),
    ],
)
def test_residence_rejects_year_precision(
    start_precision: DatePrecision,
    end_precision: DatePrecision,
) -> None:
    with pytest.raises(ValueError, match="day or month precision"):
        validate_residence_dates(
            started_on=date(2020, 1, 1),
            started_on_precision=start_precision,
            ended_on=date(2023, 12, 1),
            ended_on_precision=end_precision,
        )


def test_residence_rejects_invalid_date_range() -> None:
    with pytest.raises(ValueError, match="earlier than start"):
        validate_residence_dates(
            started_on=date(2024, 6, 1),
            started_on_precision=DatePrecision.MONTH,
            ended_on=date(2024, 5, 1),
            ended_on_precision=DatePrecision.MONTH,
        )


def test_residence_accepts_matching_city_country() -> None:
    validate_residence_destination(
        country_code="PT",
        city_country_code="PT",
    )


def test_residence_accepts_country_without_city() -> None:
    validate_residence_destination(
        country_code="PT",
        city_country_code=None,
    )


def test_residence_rejects_mismatched_city_country() -> None:
    with pytest.raises(ValueError, match="selected country"):
        validate_residence_destination(
            country_code="PT",
            city_country_code="ES",
        )


def test_exact_residences_with_overlapping_dates_are_certain() -> None:
    first = period(
        date(2024, 1, 10),
        date(2024, 5, 20),
        start_precision=DatePrecision.DAY,
        end_precision=DatePrecision.DAY,
    )

    second = period(
        date(2024, 3, 10),
        date(2024, 6, 20),
        start_precision=DatePrecision.DAY,
        end_precision=DatePrecision.DAY,
    )

    assert (
        classify_residence_overlap(
            first,
            second,
        )
        == ResidenceOverlapKind.CERTAIN
    )


def test_residences_in_separate_months_do_not_overlap() -> None:
    first = period(
        date(2024, 1, 1),
        date(2024, 3, 1),
    )

    second = period(
        date(2024, 4, 1),
        date(2024, 6, 1),
    )

    assert classify_residence_overlap(first, second) is None


def test_residences_touching_same_month_have_possible_overlap() -> None:
    first = period(
        date(2024, 1, 1),
        date(2024, 3, 1),
    )

    second = period(
        date(2024, 3, 1),
        date(2024, 6, 1),
    )

    assert (
        classify_residence_overlap(
            first,
            second,
        )
        == ResidenceOverlapKind.POSSIBLE
    )


def test_monthly_residences_with_multiple_shared_months_are_certain() -> None:
    first = period(
        date(2024, 1, 1),
        date(2024, 6, 1),
    )

    second = period(
        date(2024, 3, 1),
        date(2024, 9, 1),
    )

    assert (
        classify_residence_overlap(
            first,
            second,
        )
        == ResidenceOverlapKind.CERTAIN
    )


def test_one_day_overlap_is_certain() -> None:
    first = period(
        date(2024, 1, 1),
        date(2024, 3, 10),
        start_precision=DatePrecision.DAY,
        end_precision=DatePrecision.DAY,
    )

    second = period(
        date(2024, 3, 10),
        date(2024, 6, 1),
        start_precision=DatePrecision.DAY,
        end_precision=DatePrecision.DAY,
    )

    assert (
        classify_residence_overlap(
            first,
            second,
        )
        == ResidenceOverlapKind.CERTAIN
    )


def test_exact_residences_one_day_apart_do_not_overlap() -> None:
    first = period(
        date(2024, 1, 1),
        date(2024, 3, 10),
        start_precision=DatePrecision.DAY,
        end_precision=DatePrecision.DAY,
    )

    second = period(
        date(2024, 3, 11),
        date(2024, 6, 1),
        start_precision=DatePrecision.DAY,
        end_precision=DatePrecision.DAY,
    )

    assert classify_residence_overlap(first, second) is None


def test_residence_overlap_is_symmetric() -> None:
    first = period(
        date(2024, 1, 1),
        date(2024, 3, 1),
    )

    second = period(
        date(2024, 3, 1),
        date(2024, 6, 1),
    )

    assert classify_residence_overlap(
        first,
        second,
    ) == classify_residence_overlap(second, first)


def test_residence_period_rejects_invalid_dates() -> None:
    with pytest.raises(ValueError, match="earlier than start"):
        period(
            date(2024, 7, 1),
            date(2024, 6, 1),
        )
