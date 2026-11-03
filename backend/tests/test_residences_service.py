"""Tests for historical residence application services."""

from datetime import date
from unittest.mock import Mock
from uuid import uuid4

import pytest

from app.domain.residences import (
    ResidenceOverlapKind,
    ResidencePeriod,
)
from app.domain.visit_dates import DatePrecision
from app.models.residence import Residence
from app.repositories.residences import ResidenceRepository
from app.services.residences import (
    ResidenceDestinationNotFound,
    find_overlapping_residences,
    validate_residence_location,
)
from app.schemas.residences import ResidenceOverlapConfirmation

from app.services.residences import (
    ResidenceOverlapRequired,
    ResidenceOverlapStale,
    residence_overlap_state,
    residence_requested_state,
    residence_target_state,
    validate_residence_overlap_confirmation,
)
from app.services.residences import ResidenceOverlap


def make_repository() -> Mock:
    return Mock(spec=ResidenceRepository)


def make_period(
    start: date,
    end: date,
    *,
    start_precision: DatePrecision = DatePrecision.MONTH,
    end_precision: DatePrecision = DatePrecision.MONTH,
) -> ResidencePeriod:
    return ResidencePeriod(
        started_on=start,
        started_on_precision=start_precision,
        ended_on=end,
        ended_on_precision=end_precision,
    )


def make_residence(
    user_id,
    *,
    country_code: str = "PT",
    city_id: int | None = 2267057,
    started_on: date = date(2020, 1, 1),
    ended_on: date = date(2023, 12, 1),
) -> Residence:
    return Residence(
        id=uuid4(),
        user_id=user_id,
        country_code=country_code,
        city_id=city_id,
        started_on=started_on,
        started_on_precision="month",
        ended_on=ended_on,
        ended_on_precision="month",
    )


def test_valid_country_only_residence() -> None:
    repository = make_repository()

    repository.get_country.return_value = Mock(code="PT")

    validate_residence_location(
        repository=repository,
        country_code="PT",
        city_id=None,
    )

    repository.get_country.assert_called_once_with("PT")
    repository.get_city.assert_not_called()


def test_valid_city_residence() -> None:
    repository = make_repository()

    repository.get_country.return_value = Mock(code="PT")
    repository.get_city.return_value = Mock(
        id=2267057,
        country_code="PT",
    )

    validate_residence_location(
        repository=repository,
        country_code="PT",
        city_id=2267057,
    )


def test_nonexistent_country_is_rejected() -> None:
    repository = make_repository()

    repository.get_country.return_value = None

    with pytest.raises(
        ResidenceDestinationNotFound,
        match="Country not found",
    ):
        validate_residence_location(
            repository=repository,
            country_code="XX",
            city_id=None,
        )


def test_nonexistent_city_is_rejected() -> None:
    repository = make_repository()

    repository.get_country.return_value = Mock(code="PT")
    repository.get_city.return_value = None

    with pytest.raises(
        ResidenceDestinationNotFound,
        match="City not found",
    ):
        validate_residence_location(
            repository=repository,
            country_code="PT",
            city_id=999999999,
        )


def test_city_country_mismatch_is_rejected() -> None:
    repository = make_repository()

    repository.get_country.return_value = Mock(code="PT")
    repository.get_city.return_value = Mock(
        id=2267057,
        country_code="PT",
    )

    with pytest.raises(ValueError, match="selected country"):
        validate_residence_location(
            repository=repository,
            country_code="ES",
            city_id=2267057,
        )


def test_no_overlaps_returns_empty_list() -> None:
    repository = make_repository()
    user_id = uuid4()

    repository.list_for_user.return_value = [
        make_residence(
            user_id,
            started_on=date(2020, 1, 1),
            ended_on=date(2020, 12, 1),
        )
    ]

    proposed = make_period(
        date(2024, 1, 1),
        date(2024, 12, 1),
    )

    overlaps = find_overlapping_residences(
        repository=repository,
        user_id=user_id,
        proposed_period=proposed,
    )

    assert overlaps == []

    repository.list_for_user.assert_called_once_with(user_id)


def test_certain_overlap_is_detected() -> None:
    repository = make_repository()
    user_id = uuid4()

    existing = make_residence(user_id)

    repository.list_for_user.return_value = [existing]

    proposed = make_period(
        date(2022, 1, 1),
        date(2022, 12, 1),
    )

    overlaps = find_overlapping_residences(
        repository=repository,
        user_id=user_id,
        proposed_period=proposed,
    )

    assert len(overlaps) == 1
    assert overlaps[0].residence.id == existing.id
    assert overlaps[0].kind == ResidenceOverlapKind.CERTAIN


def test_possible_overlap_is_detected() -> None:
    repository = make_repository()
    user_id = uuid4()

    existing = make_residence(
        user_id,
        started_on=date(2020, 1, 1),
        ended_on=date(2023, 3, 1),
    )

    repository.list_for_user.return_value = [existing]

    proposed = make_period(
        date(2023, 3, 1),
        date(2024, 6, 1),
    )

    overlaps = find_overlapping_residences(
        repository=repository,
        user_id=user_id,
        proposed_period=proposed,
    )

    assert len(overlaps) == 1
    assert overlaps[0].kind == ResidenceOverlapKind.POSSIBLE


def test_all_overlaps_are_returned() -> None:
    repository = make_repository()
    user_id = uuid4()

    lisbon = make_residence(
        user_id,
        city_id=2267057,
        started_on=date(2020, 1, 1),
        ended_on=date(2023, 12, 1),
    )

    porto = make_residence(
        user_id,
        city_id=2735943,
        started_on=date(2022, 9, 1),
        ended_on=date(2024, 6, 1),
    )

    unrelated = make_residence(
        user_id,
        city_id=None,
        country_code="FR",
        started_on=date(2015, 1, 1),
        ended_on=date(2016, 12, 1),
    )

    repository.list_for_user.return_value = [
        lisbon,
        porto,
        unrelated,
    ]

    proposed = make_period(
        date(2023, 3, 1),
        date(2023, 10, 1),
    )

    overlaps = find_overlapping_residences(
        repository=repository,
        user_id=user_id,
        proposed_period=proposed,
    )

    assert len(overlaps) == 2

    overlap_ids = {overlap.residence.id for overlap in overlaps}

    assert overlap_ids == {
        lisbon.id,
        porto.id,
    }


def test_overlap_detection_is_independent_of_country() -> None:
    repository = make_repository()
    user_id = uuid4()

    existing = make_residence(
        user_id,
        country_code="PT",
    )

    repository.list_for_user.return_value = [existing]

    proposed = make_period(
        date(2022, 1, 1),
        date(2022, 12, 1),
    )

    overlaps = find_overlapping_residences(
        repository=repository,
        user_id=user_id,
        proposed_period=proposed,
    )

    assert len(overlaps) == 1


def test_update_excludes_edited_residence() -> None:
    repository = make_repository()
    user_id = uuid4()

    existing = make_residence(user_id)

    repository.list_for_user.return_value = [existing]

    proposed = make_period(
        date(2021, 1, 1),
        date(2022, 12, 1),
    )

    overlaps = find_overlapping_residences(
        repository=repository,
        user_id=user_id,
        proposed_period=proposed,
        exclude_residence_id=existing.id,
    )

    assert overlaps == []


def test_update_still_detects_other_residences() -> None:
    repository = make_repository()
    user_id = uuid4()

    edited = make_residence(user_id)

    another = make_residence(
        user_id,
        city_id=2735943,
    )

    repository.list_for_user.return_value = [
        edited,
        another,
    ]

    proposed = make_period(
        date(2022, 1, 1),
        date(2022, 12, 1),
    )

    overlaps = find_overlapping_residences(
        repository=repository,
        user_id=user_id,
        proposed_period=proposed,
        exclude_residence_id=edited.id,
    )

    assert len(overlaps) == 1
    assert overlaps[0].residence.id == another.id


def make_confirmation_scenario():
    """Build a requested residence and one overlapping residence."""

    user_id = uuid4()

    existing = make_residence(user_id)

    requested = residence_requested_state(
        country_code="ES",
        city_id=None,
        period=make_period(
            date(2022, 1, 1),
            date(2022, 12, 1),
        ),
    )

    overlap = ResidenceOverlap(
        residence=existing,
        kind=ResidenceOverlapKind.CERTAIN,
    )

    return requested, overlap


def test_no_overlap_requires_no_confirmation() -> None:
    requested, _ = make_confirmation_scenario()

    validate_residence_overlap_confirmation(
        requested=requested,
        overlaps=[],
        confirmation=None,
    )


def test_overlap_requires_explicit_confirmation() -> None:
    requested, overlap = make_confirmation_scenario()

    with pytest.raises(ResidenceOverlapRequired) as exc:
        validate_residence_overlap_confirmation(
            requested=requested,
            overlaps=[overlap],
            confirmation=None,
        )

    assert exc.value.requested == requested
    assert len(exc.value.overlaps) == 1
    assert exc.value.overlaps[0].residence_id == overlap.residence.id
    assert exc.value.expected_target is None


def test_exact_overlap_confirmation_is_accepted() -> None:
    requested, overlap = make_confirmation_scenario()

    confirmation = ResidenceOverlapConfirmation(
        requested=requested,
        overlaps=[residence_overlap_state(overlap)],
    )

    validate_residence_overlap_confirmation(
        requested=requested,
        overlaps=[overlap],
        confirmation=confirmation,
    )


def test_confirmation_rejects_changed_requested_residence() -> None:
    requested, overlap = make_confirmation_scenario()

    changed_request = requested.model_copy(update={"country_code": "FR"})

    confirmation = ResidenceOverlapConfirmation(
        requested=requested,
        overlaps=[residence_overlap_state(overlap)],
    )

    with pytest.raises(
        ResidenceOverlapStale,
        match="requested residence has changed",
    ):
        validate_residence_overlap_confirmation(
            requested=changed_request,
            overlaps=[overlap],
            confirmation=confirmation,
        )


def test_confirmation_rejects_changed_overlap_dates() -> None:
    requested, overlap = make_confirmation_scenario()

    confirmation = ResidenceOverlapConfirmation(
        requested=requested,
        overlaps=[residence_overlap_state(overlap)],
    )

    overlap.residence.ended_on = date(2024, 12, 1)

    with pytest.raises(
        ResidenceOverlapStale,
        match="overlapping residences have changed",
    ):
        validate_residence_overlap_confirmation(
            requested=requested,
            overlaps=[overlap],
            confirmation=confirmation,
        )


def test_confirmation_rejects_additional_overlap() -> None:
    requested, overlap = make_confirmation_scenario()

    confirmation = ResidenceOverlapConfirmation(
        requested=requested,
        overlaps=[residence_overlap_state(overlap)],
    )

    another = ResidenceOverlap(
        residence=make_residence(uuid4()),
        kind=ResidenceOverlapKind.CERTAIN,
    )

    with pytest.raises(ResidenceOverlapStale):
        validate_residence_overlap_confirmation(
            requested=requested,
            overlaps=[overlap, another],
            confirmation=confirmation,
        )


def test_confirmation_rejects_removed_overlap() -> None:
    requested, overlap = make_confirmation_scenario()

    confirmation = ResidenceOverlapConfirmation(
        requested=requested,
        overlaps=[residence_overlap_state(overlap)],
    )

    with pytest.raises(ResidenceOverlapStale):
        validate_residence_overlap_confirmation(
            requested=requested,
            overlaps=[],
            confirmation=confirmation,
        )


def test_confirmation_rejects_duplicate_overlap_entries() -> None:
    requested, overlap = make_confirmation_scenario()

    snapshot = residence_overlap_state(overlap)

    confirmation = ResidenceOverlapConfirmation(
        requested=requested,
        overlaps=[snapshot, snapshot],
    )

    with pytest.raises(
        ResidenceOverlapStale,
        match="duplicate",
    ):
        validate_residence_overlap_confirmation(
            requested=requested,
            overlaps=[overlap],
            confirmation=confirmation,
        )


def test_update_confirmation_requires_original_target() -> None:
    requested, overlap = make_confirmation_scenario()

    target = make_residence(
        uuid4(),
        started_on=date(2018, 1, 1),
        ended_on=date(2019, 12, 1),
    )

    confirmation = ResidenceOverlapConfirmation(
        requested=requested,
        overlaps=[residence_overlap_state(overlap)],
        expected_target=None,
    )

    with pytest.raises(
        ResidenceOverlapStale,
        match="edited residence has changed",
    ):
        validate_residence_overlap_confirmation(
            requested=requested,
            overlaps=[overlap],
            confirmation=confirmation,
            existing_residence=target,
        )


def test_update_confirmation_accepts_matching_target() -> None:
    requested, overlap = make_confirmation_scenario()

    target = make_residence(
        uuid4(),
        started_on=date(2018, 1, 1),
        ended_on=date(2019, 12, 1),
    )

    confirmation = ResidenceOverlapConfirmation(
        requested=requested,
        overlaps=[residence_overlap_state(overlap)],
        expected_target=residence_target_state(target),
    )

    validate_residence_overlap_confirmation(
        requested=requested,
        overlaps=[overlap],
        confirmation=confirmation,
        existing_residence=target,
    )


def test_update_confirmation_rejects_changed_target() -> None:
    requested, overlap = make_confirmation_scenario()

    target = make_residence(
        uuid4(),
        started_on=date(2018, 1, 1),
        ended_on=date(2019, 12, 1),
    )

    confirmation = ResidenceOverlapConfirmation(
        requested=requested,
        overlaps=[residence_overlap_state(overlap)],
        expected_target=residence_target_state(target),
    )

    target.ended_on = date(2020, 12, 1)

    with pytest.raises(
        ResidenceOverlapStale,
        match="edited residence has changed",
    ):
        validate_residence_overlap_confirmation(
            requested=requested,
            overlaps=[overlap],
            confirmation=confirmation,
            existing_residence=target,
        )
