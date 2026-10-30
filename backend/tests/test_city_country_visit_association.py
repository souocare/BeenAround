"""Tests for explicit city-to-country visit association rules."""

from datetime import date

import pytest

from app.domain.city_country_visit_association import (
    CountryVisitDateExpansion,
    VisitDateRange,
    propose_country_visit_date_expansion,
    validate_city_country_association,
    validate_country_date_expansion_confirmation,
)
from app.domain.visit_dates import DatePrecision


def dates(
    start: date,
    end: date,
    *,
    start_precision: DatePrecision = DatePrecision.DAY,
    end_precision: DatePrecision = DatePrecision.DAY,
) -> VisitDateRange:
    return VisitDateRange(
        started_on=start,
        started_on_precision=start_precision,
        ended_on=end,
        ended_on_precision=end_precision,
    )


def test_city_can_be_associated_with_matching_country() -> None:
    validate_city_country_association(
        city_country_code="PT",
        country_visit_country_code="PT",
        city_dates=dates(
            date(2025, 6, 12),
            date(2025, 6, 15),
        ),
        country_dates=dates(
            date(2025, 6, 10),
            date(2025, 6, 20),
        ),
    )


def test_city_cannot_be_associated_with_different_country() -> None:
    with pytest.raises(ValueError, match="same country"):
        validate_city_country_association(
            city_country_code="ES",
            country_visit_country_code="PT",
            city_dates=dates(
                date(2025, 6, 12),
                date(2025, 6, 15),
            ),
            country_dates=dates(
                date(2025, 6, 10),
                date(2025, 6, 20),
            ),
        )


@pytest.mark.parametrize(
    ("city_start", "city_end"),
    [
        (date(2025, 6, 9), date(2025, 6, 15)),
        (date(2025, 6, 12), date(2025, 6, 21)),
        (date(2025, 6, 9), date(2025, 6, 21)),
    ],
)
def test_city_dates_outside_country_visit_require_expansion(
    city_start: date,
    city_end: date,
) -> None:
    with pytest.raises(ValueError, match="extend beyond"):
        validate_city_country_association(
            city_country_code="PT",
            country_visit_country_code="PT",
            city_dates=dates(city_start, city_end),
            country_dates=dates(
                date(2025, 6, 10),
                date(2025, 6, 20),
            ),
        )


def test_exact_city_dates_fit_month_precision_country_visit() -> None:
    validate_city_country_association(
        city_country_code="PT",
        country_visit_country_code="PT",
        city_dates=dates(
            date(2025, 6, 10),
            date(2025, 6, 12),
        ),
        country_dates=dates(
            date(2025, 6, 1),
            date(2025, 6, 1),
            start_precision=DatePrecision.MONTH,
            end_precision=DatePrecision.MONTH,
        ),
    )


def test_month_precision_city_dates_exceed_exact_country_visit() -> None:
    with pytest.raises(ValueError, match="extend beyond"):
        validate_city_country_association(
            city_country_code="PT",
            country_visit_country_code="PT",
            city_dates=dates(
                date(2025, 6, 1),
                date(2025, 6, 1),
                start_precision=DatePrecision.MONTH,
                end_precision=DatePrecision.MONTH,
            ),
            country_dates=dates(
                date(2025, 6, 10),
                date(2025, 6, 20),
            ),
        )


def test_year_precision_country_visit_contains_exact_city_dates() -> None:
    validate_city_country_association(
        city_country_code="PT",
        country_visit_country_code="PT",
        city_dates=dates(
            date(2025, 6, 10),
            date(2025, 6, 12),
        ),
        country_dates=dates(
            date(2025, 1, 1),
            date(2025, 1, 1),
            start_precision=DatePrecision.YEAR,
            end_precision=DatePrecision.YEAR,
        ),
    )


def test_year_precision_city_requires_expansion_of_exact_country_visit() -> None:
    with pytest.raises(ValueError, match="extend beyond"):
        validate_city_country_association(
            city_country_code="PT",
            country_visit_country_code="PT",
            city_dates=dates(
                date(2025, 1, 1),
                date(2025, 1, 1),
                start_precision=DatePrecision.YEAR,
                end_precision=DatePrecision.YEAR,
            ),
            country_dates=dates(
                date(2025, 6, 10),
                date(2025, 6, 20),
            ),
        )


def test_country_date_expansion_not_needed() -> None:
    proposal = propose_country_visit_date_expansion(
        city_country_code="PT",
        country_visit_country_code="PT",
        city_dates=dates(
            date(2025, 6, 12),
            date(2025, 6, 15),
        ),
        country_dates=dates(
            date(2025, 6, 10),
            date(2025, 6, 20),
        ),
    )

    assert proposal is None


def test_country_date_expansion_extends_end() -> None:
    proposal = propose_country_visit_date_expansion(
        city_country_code="PT",
        country_visit_country_code="PT",
        city_dates=dates(
            date(2025, 6, 12),
            date(2025, 6, 25),
        ),
        country_dates=dates(
            date(2025, 6, 10),
            date(2025, 6, 20),
        ),
    )

    assert proposal == CountryVisitDateExpansion(
        started_on=date(2025, 6, 10),
        started_on_precision=DatePrecision.DAY,
        ended_on=date(2025, 6, 25),
        ended_on_precision=DatePrecision.DAY,
    )


def test_country_date_expansion_extends_start() -> None:
    proposal = propose_country_visit_date_expansion(
        city_country_code="PT",
        country_visit_country_code="PT",
        city_dates=dates(
            date(2025, 6, 5),
            date(2025, 6, 15),
        ),
        country_dates=dates(
            date(2025, 6, 10),
            date(2025, 6, 20),
        ),
    )

    assert proposal is not None

    assert proposal.started_on == date(2025, 6, 5)
    assert proposal.ended_on == date(2025, 6, 20)


def test_country_date_expansion_extends_both_boundaries() -> None:
    proposal = propose_country_visit_date_expansion(
        city_country_code="PT",
        country_visit_country_code="PT",
        city_dates=dates(
            date(2025, 6, 5),
            date(2025, 6, 25),
        ),
        country_dates=dates(
            date(2025, 6, 10),
            date(2025, 6, 20),
        ),
    )

    assert proposal is not None

    assert proposal.started_on == date(2025, 6, 5)
    assert proposal.ended_on == date(2025, 6, 25)


def test_country_date_expansion_preserves_month_precision() -> None:
    proposal = propose_country_visit_date_expansion(
        city_country_code="PT",
        country_visit_country_code="PT",
        city_dates=dates(
            date(2025, 6, 12),
            date(2025, 7, 1),
            end_precision=DatePrecision.MONTH,
        ),
        country_dates=dates(
            date(2025, 6, 10),
            date(2025, 6, 20),
        ),
    )

    assert proposal is not None

    assert proposal.ended_on == date(2025, 7, 1)
    assert proposal.ended_on_precision == DatePrecision.MONTH


def test_country_date_expansion_preserves_year_precision() -> None:
    proposal = propose_country_visit_date_expansion(
        city_country_code="PT",
        country_visit_country_code="PT",
        city_dates=dates(
            date(2024, 1, 1),
            date(2025, 6, 15),
            start_precision=DatePrecision.YEAR,
        ),
        country_dates=dates(
            date(2025, 6, 10),
            date(2025, 6, 20),
        ),
    )

    assert proposal is not None

    assert proposal.started_on == date(2024, 1, 1)
    assert proposal.started_on_precision == DatePrecision.YEAR


def test_country_date_expansion_rejects_different_country() -> None:
    with pytest.raises(ValueError, match="same country"):
        propose_country_visit_date_expansion(
            city_country_code="ES",
            country_visit_country_code="PT",
            city_dates=dates(
                date(2025, 6, 12),
                date(2025, 6, 25),
            ),
            country_dates=dates(
                date(2025, 6, 10),
                date(2025, 6, 20),
            ),
        )


def test_country_expansion_confirmation_accepts_matching_proposal() -> None:
    current = dates(
        date(2025, 6, 10),
        date(2025, 6, 15),
    )

    proposal = CountryVisitDateExpansion(
        started_on=date(2025, 6, 10),
        started_on_precision=DatePrecision.DAY,
        ended_on=date(2025, 6, 18),
        ended_on_precision=DatePrecision.DAY,
    )

    validate_country_date_expansion_confirmation(
        current=current,
        expected=current,
        proposed=proposal,
        confirmed=proposal.date_range,
    )


def test_country_expansion_confirmation_rejects_stale_country_dates() -> None:
    proposal = CountryVisitDateExpansion(
        started_on=date(2025, 6, 10),
        started_on_precision=DatePrecision.DAY,
        ended_on=date(2025, 6, 18),
        ended_on_precision=DatePrecision.DAY,
    )

    with pytest.raises(ValueError, match="have changed"):
        validate_country_date_expansion_confirmation(
            current=dates(
                date(2025, 6, 10),
                date(2025, 6, 16),
            ),
            expected=dates(
                date(2025, 6, 10),
                date(2025, 6, 15),
            ),
            proposed=proposal,
            confirmed=proposal.date_range,
        )


def test_country_expansion_confirmation_rejects_modified_proposal() -> None:
    current = dates(
        date(2025, 6, 10),
        date(2025, 6, 15),
    )

    proposal = CountryVisitDateExpansion(
        started_on=date(2025, 6, 10),
        started_on_precision=DatePrecision.DAY,
        ended_on=date(2025, 6, 18),
        ended_on_precision=DatePrecision.DAY,
    )

    with pytest.raises(ValueError, match="do not match"):
        validate_country_date_expansion_confirmation(
            current=current,
            expected=current,
            proposed=proposal,
            confirmed=dates(
                date(2025, 6, 10),
                date(2025, 6, 25),
            ),
        )


def test_country_expansion_confirmation_rejects_unnecessary_expansion() -> None:
    current = dates(
        date(2025, 6, 10),
        date(2025, 6, 20),
    )

    with pytest.raises(ValueError, match="no longer required"):
        validate_country_date_expansion_confirmation(
            current=current,
            expected=current,
            proposed=None,
            confirmed=dates(
                date(2025, 6, 10),
                date(2025, 6, 25),
            ),
        )
