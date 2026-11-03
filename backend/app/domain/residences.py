"""Domain rules for historical residences."""

from dataclasses import dataclass
from datetime import date
from enum import StrEnum

from app.domain.visit_dates import (
    DatePrecision,
    partial_date_bounds,
    validate_partial_visit_dates,
)


class ResidenceOverlapKind(StrEnum):
    """Classification of temporal overlap between residences."""

    CERTAIN = "certain"
    POSSIBLE = "possible"


@dataclass(frozen=True)
class ResidencePeriod:
    """A validated historical residence date interval."""

    started_on: date
    started_on_precision: DatePrecision
    ended_on: date
    ended_on_precision: DatePrecision

    def __post_init__(self) -> None:
        normalized_start, normalized_end = validate_residence_dates(
            started_on=self.started_on,
            started_on_precision=self.started_on_precision,
            ended_on=self.ended_on,
            ended_on_precision=self.ended_on_precision,
        )

        object.__setattr__(self, "started_on", normalized_start)
        object.__setattr__(self, "ended_on", normalized_end)


def validate_residence_dates(
    *,
    started_on: date,
    started_on_precision: DatePrecision,
    ended_on: date,
    ended_on_precision: DatePrecision,
) -> tuple[date, date]:
    """Validate residence dates requiring at least month precision."""

    allowed_precisions = {
        DatePrecision.DAY,
        DatePrecision.MONTH,
    }

    if started_on_precision not in allowed_precisions:
        raise ValueError("Residence start date requires day or month precision.")

    if ended_on_precision not in allowed_precisions:
        raise ValueError("Residence end date requires day or month precision.")

    normalized_start, normalized_end = validate_partial_visit_dates(
        started_on,
        started_on_precision,
        ended_on,
        ended_on_precision,
    )

    assert normalized_start is not None
    assert normalized_end is not None

    return normalized_start, normalized_end


def validate_residence_destination(
    *,
    country_code: str,
    city_country_code: str | None,
) -> None:
    """Validate the geographical compatibility of a residence."""

    if city_country_code is None:
        return

    if country_code != city_country_code:
        raise ValueError("Residence city must belong to the selected country.")


def classify_residence_overlap(
    first: ResidencePeriod,
    second: ResidencePeriod,
) -> ResidenceOverlapKind | None:
    """Classify overlap while respecting partial-date uncertainty.

    CERTAIN:
        The intervals overlap regardless of unknown days.

    POSSIBLE:
        The intervals may overlap depending on unknown days.

    None:
        The intervals cannot overlap.
    """

    first_start_earliest, first_start_latest = partial_date_bounds(
        first.started_on,
        first.started_on_precision,
    )

    first_end_earliest, first_end_latest = partial_date_bounds(
        first.ended_on,
        first.ended_on_precision,
    )

    second_start_earliest, second_start_latest = partial_date_bounds(
        second.started_on,
        second.started_on_precision,
    )

    second_end_earliest, second_end_latest = partial_date_bounds(
        second.ended_on,
        second.ended_on_precision,
    )

    # No overlap is possible if the earliest potential starts
    # occur after the latest potential ends.
    if first_start_earliest > second_end_latest or second_start_earliest > first_end_latest:
        return None

    # Overlap is certain when even the latest possible starts
    # occur before the earliest possible ends.
    if first_start_latest <= second_end_earliest and second_start_latest <= first_end_earliest:
        return ResidenceOverlapKind.CERTAIN

    return ResidenceOverlapKind.POSSIBLE
