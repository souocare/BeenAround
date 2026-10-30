"""Domain rules for explicit city-to-country visit associations."""

from dataclasses import dataclass
from datetime import date

from app.domain.visit_dates import DatePrecision, partial_date_bounds


@dataclass(frozen=True, slots=True)
class VisitDateRange:
    """A visit date range with explicit boundary precisions."""

    started_on: date
    started_on_precision: DatePrecision
    ended_on: date
    ended_on_precision: DatePrecision


def validate_city_country_association(
    *,
    city_country_code: str,
    country_visit_country_code: str,
    city_dates: VisitDateRange,
    country_dates: VisitDateRange,
) -> None:
    """Validate the geographic and temporal compatibility of an association.

    Raises ValueError when the association would require user confirmation
    or when the city belongs to another country.
    """

    if city_country_code != country_visit_country_code:
        raise ValueError("City and country visit must belong to the same country.")

    city_start, _ = partial_date_bounds(
        city_dates.started_on,
        city_dates.started_on_precision,
    )

    _, city_end = partial_date_bounds(
        city_dates.ended_on,
        city_dates.ended_on_precision,
    )

    country_start, _ = partial_date_bounds(
        country_dates.started_on,
        country_dates.started_on_precision,
    )

    _, country_end = partial_date_bounds(
        country_dates.ended_on,
        country_dates.ended_on_precision,
    )

    if city_start < country_start or city_end > country_end:
        raise ValueError("City visit dates extend beyond the country visit date range.")


@dataclass(frozen=True, slots=True)
class CountryVisitDateExpansion:
    """Proposed country visit dates after including a city visit."""

    started_on: date
    started_on_precision: DatePrecision
    ended_on: date
    ended_on_precision: DatePrecision

    @property
    def date_range(self) -> VisitDateRange:
        return VisitDateRange(
            started_on=self.started_on,
            started_on_precision=self.started_on_precision,
            ended_on=self.ended_on,
            ended_on_precision=self.ended_on_precision,
        )


def propose_country_visit_date_expansion(
    *,
    city_country_code: str,
    country_visit_country_code: str,
    city_dates: VisitDateRange,
    country_dates: VisitDateRange,
) -> CountryVisitDateExpansion | None:
    """Propose the minimum boundary changes needed to include a city visit.

    Existing country boundaries are preserved whenever they already
    contain the city visit. Expanded boundaries inherit the city's
    corresponding date precision.

    This function never persists changes or confirms an association.
    """

    if city_country_code != country_visit_country_code:
        raise ValueError("City and country visit must belong to the same country.")

    city_start, _ = partial_date_bounds(
        city_dates.started_on,
        city_dates.started_on_precision,
    )

    _, city_end = partial_date_bounds(
        city_dates.ended_on,
        city_dates.ended_on_precision,
    )

    country_start, _ = partial_date_bounds(
        country_dates.started_on,
        country_dates.started_on_precision,
    )

    _, country_end = partial_date_bounds(
        country_dates.ended_on,
        country_dates.ended_on_precision,
    )

    expand_start = city_start < country_start
    expand_end = city_end > country_end

    if not expand_start and not expand_end:
        return None

    proposal = CountryVisitDateExpansion(
        started_on=(city_dates.started_on if expand_start else country_dates.started_on),
        started_on_precision=(
            city_dates.started_on_precision if expand_start else country_dates.started_on_precision
        ),
        ended_on=(city_dates.ended_on if expand_end else country_dates.ended_on),
        ended_on_precision=(
            city_dates.ended_on_precision if expand_end else country_dates.ended_on_precision
        ),
    )

    # Verify that the proposed interval genuinely contains the city.
    validate_city_country_association(
        city_country_code=city_country_code,
        country_visit_country_code=country_visit_country_code,
        city_dates=city_dates,
        country_dates=proposal.date_range,
    )

    return proposal


def validate_country_date_expansion_confirmation(
    *,
    current: VisitDateRange,
    expected: VisitDateRange,
    proposed: CountryVisitDateExpansion | None,
    confirmed: VisitDateRange,
) -> None:
    """Validate approval of the exact country date expansion shown to the user."""

    if current != expected:
        raise ValueError("Country visit dates have changed since the expansion was proposed.")

    if proposed is None:
        raise ValueError("Country visit date expansion is no longer required.")

    if proposed.date_range != confirmed:
        raise ValueError("Confirmed country visit dates do not match the current proposal.")
