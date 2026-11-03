"""Application services for historical residences."""

from dataclasses import dataclass
from uuid import UUID

from app.domain.residences import (
    ResidenceOverlapKind,
    ResidencePeriod,
    classify_residence_overlap,
    validate_residence_destination,
)
from app.domain.visit_dates import DatePrecision
from app.models.residence import Residence
from app.repositories.residences import ResidenceRepository
from app.schemas.residences import (
    ResidenceOverlapConfirmation,
    ResidenceOverlapState,
    ResidenceRequestedState,
    ResidenceTargetState,
)


class ResidenceDestinationNotFound(Exception):
    """The requested country or city does not exist."""


class ResidenceOverlapRequired(Exception):
    """Existing residences overlap with the requested period."""

    def __init__(
        self,
        *,
        requested: ResidenceRequestedState,
        overlaps: list[ResidenceOverlapState],
        expected_target: ResidenceTargetState | None,
    ) -> None:
        self.requested = requested
        self.overlaps = overlaps
        self.expected_target = expected_target

        super().__init__("This residence overlaps with existing residences.")


class ResidenceOverlapStale(Exception):
    """An overlap confirmation no longer matches the current state."""


@dataclass(frozen=True)
class ResidenceOverlap:
    """An existing residence overlapping the requested period."""

    residence: Residence
    kind: ResidenceOverlapKind


def validate_residence_location(
    *,
    repository: ResidenceRepository,
    country_code: str,
    city_id: int | None,
) -> None:
    """Validate the requested country and optional city."""

    country = repository.get_country(country_code)

    if country is None:
        raise ResidenceDestinationNotFound("Country not found.")

    if city_id is None:
        return

    city = repository.get_city(city_id)

    if city is None:
        raise ResidenceDestinationNotFound("City not found.")

    validate_residence_destination(
        country_code=country_code,
        city_country_code=city.country_code,
    )


def residence_period(
    residence: Residence,
) -> ResidencePeriod:
    """Convert a stored residence into a validated domain period."""

    return ResidencePeriod(
        started_on=residence.started_on,
        started_on_precision=DatePrecision(residence.started_on_precision),
        ended_on=residence.ended_on,
        ended_on_precision=DatePrecision(residence.ended_on_precision),
    )


def find_overlapping_residences(
    *,
    repository: ResidenceRepository,
    user_id: UUID,
    proposed_period: ResidencePeriod,
    exclude_residence_id: UUID | None = None,
) -> list[ResidenceOverlap]:
    """Find every residence overlapping a proposed period.

    Only residences belonging to the specified user are considered.

    During updates, the edited residence can be excluded.

    This function never modifies or persists records.
    """

    existing_residences = repository.list_for_user(user_id)

    overlaps: list[ResidenceOverlap] = []

    for existing in existing_residences:
        if existing.id == exclude_residence_id:
            continue

        existing_period = residence_period(existing)

        overlap_kind = classify_residence_overlap(
            proposed_period,
            existing_period,
        )

        if overlap_kind is None:
            continue

        overlaps.append(
            ResidenceOverlap(
                residence=existing,
                kind=overlap_kind,
            )
        )

    return overlaps


def residence_requested_state(
    *,
    country_code: str,
    city_id: int | None,
    period: ResidencePeriod,
) -> ResidenceRequestedState:
    """Build the canonical state of a requested residence."""

    return ResidenceRequestedState(
        country_code=country_code,
        city_id=city_id,
        started_on=period.started_on,
        started_on_precision=period.started_on_precision,
        ended_on=period.ended_on,
        ended_on_precision=period.ended_on_precision,
    )


def residence_target_state(
    residence: Residence,
) -> ResidenceTargetState:
    """Build an exact snapshot of an existing residence."""

    period = residence_period(residence)

    return ResidenceTargetState(
        residence_id=residence.id,
        country_code=residence.country_code,
        city_id=residence.city_id,
        started_on=period.started_on,
        started_on_precision=period.started_on_precision,
        ended_on=period.ended_on,
        ended_on_precision=period.ended_on_precision,
    )


def residence_overlap_state(
    overlap: ResidenceOverlap,
) -> ResidenceOverlapState:
    """Build a snapshot of an existing overlapping residence."""

    residence = overlap.residence
    period = residence_period(residence)

    return ResidenceOverlapState(
        residence_id=residence.id,
        kind=overlap.kind,
        country_code=residence.country_code,
        city_id=residence.city_id,
        started_on=period.started_on,
        started_on_precision=period.started_on_precision,
        ended_on=period.ended_on,
        ended_on_precision=period.ended_on_precision,
    )


def validate_residence_overlap_confirmation(
    *,
    requested: ResidenceRequestedState,
    overlaps: list[ResidenceOverlap],
    confirmation: ResidenceOverlapConfirmation | None,
    existing_residence: Residence | None = None,
) -> None:
    """Require confirmation of exactly the current overlapping residences.

    The confirmation must match:
    - The requested destination and date interval.
    - Every overlapping residence and its current state.
    - The original residence state when editing.

    This function does not persist any records.
    """

    current_overlaps = [residence_overlap_state(overlap) for overlap in overlaps]

    current_overlaps.sort(key=lambda overlap: str(overlap.residence_id))

    expected_target = (
        residence_target_state(existing_residence) if existing_residence is not None else None
    )

    if not current_overlaps:
        if confirmation is not None:
            raise ResidenceOverlapStale("Residence overlap confirmation is no longer required.")

        return

    if confirmation is None:
        raise ResidenceOverlapRequired(
            requested=requested,
            overlaps=current_overlaps,
            expected_target=expected_target,
        )

    confirmed_overlaps = sorted(
        confirmation.overlaps,
        key=lambda overlap: str(overlap.residence_id),
    )

    confirmed_ids = [overlap.residence_id for overlap in confirmed_overlaps]

    if len(confirmed_ids) != len(set(confirmed_ids)):
        raise ResidenceOverlapStale("Residence overlap confirmation contains duplicate entries.")

    if confirmation.requested != requested:
        raise ResidenceOverlapStale("The requested residence has changed since confirmation.")

    if confirmed_overlaps != current_overlaps:
        raise ResidenceOverlapStale("The overlapping residences have changed since confirmation.")

    if confirmation.expected_target != expected_target:
        raise ResidenceOverlapStale("The edited residence has changed since confirmation.")
