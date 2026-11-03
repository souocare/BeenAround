"""Tests for historical residence API schemas."""

from datetime import date
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.schemas.residences import (
    ResidenceCreate,
    ResidenceUpdate,
)


def valid_residence_payload() -> dict:
    return {
        "country_code": "PT",
        "city_id": 2267057,
        "started_on": "2020-01-01",
        "started_on_precision": "month",
        "ended_on": "2023-12-01",
        "ended_on_precision": "month",
    }


def test_create_accepts_month_precision() -> None:
    residence = ResidenceCreate.model_validate(valid_residence_payload())

    assert residence.country_code == "PT"
    assert residence.city_id == 2267057
    assert residence.started_on == date(2020, 1, 1)
    assert residence.started_on_precision == "month"


def test_create_accepts_country_without_city() -> None:
    payload = valid_residence_payload()
    payload["city_id"] = None

    residence = ResidenceCreate.model_validate(payload)

    assert residence.city_id is None


def test_create_normalizes_country_code() -> None:
    payload = valid_residence_payload()
    payload["country_code"] = "pt"

    residence = ResidenceCreate.model_validate(payload)

    assert residence.country_code == "PT"


def test_create_normalizes_month_dates() -> None:
    payload = valid_residence_payload()

    payload["started_on"] = "2020-01-15"
    payload["ended_on"] = "2023-12-20"

    residence = ResidenceCreate.model_validate(payload)

    assert residence.started_on == date(2020, 1, 1)
    assert residence.ended_on == date(2023, 12, 1)


@pytest.mark.parametrize(
    "field",
    [
        "started_on_precision",
        "ended_on_precision",
    ],
)
def test_create_rejects_year_precision(field: str) -> None:
    payload = valid_residence_payload()
    payload[field] = "year"

    with pytest.raises(ValidationError):
        ResidenceCreate.model_validate(payload)


@pytest.mark.parametrize(
    "field",
    [
        "started_on",
        "started_on_precision",
        "ended_on",
        "ended_on_precision",
    ],
)
def test_create_requires_dates_and_precisions(field: str) -> None:
    payload = valid_residence_payload()
    payload.pop(field)

    with pytest.raises(ValidationError):
        ResidenceCreate.model_validate(payload)


def test_create_rejects_invalid_date_range() -> None:
    payload = valid_residence_payload()

    payload["started_on"] = "2024-06-01"
    payload["ended_on"] = "2024-05-01"

    with pytest.raises(ValidationError):
        ResidenceCreate.model_validate(payload)


def test_create_rejects_unknown_fields() -> None:
    payload = valid_residence_payload()
    payload["unexpected"] = True

    with pytest.raises(ValidationError):
        ResidenceCreate.model_validate(payload)


def test_create_rejects_invalid_city_id() -> None:
    payload = valid_residence_payload()
    payload["city_id"] = -1

    with pytest.raises(ValidationError):
        ResidenceCreate.model_validate(payload)


def test_update_requires_at_least_one_field() -> None:
    with pytest.raises(ValidationError):
        ResidenceUpdate.model_validate({})


def test_update_can_remove_city() -> None:
    update = ResidenceUpdate.model_validate({"city_id": None})

    assert update.city_id is None
    assert "city_id" in update.model_fields_set


def test_update_omitted_city_is_unchanged() -> None:
    update = ResidenceUpdate.model_validate({"country_code": "ES"})

    assert "city_id" not in update.model_fields_set


def test_update_rejects_null_country_code() -> None:
    with pytest.raises(ValidationError):
        ResidenceUpdate.model_validate({"country_code": None})


@pytest.mark.parametrize(
    "field",
    [
        "started_on",
        "started_on_precision",
        "ended_on",
        "ended_on_precision",
    ],
)
def test_update_rejects_null_required_dates(field: str) -> None:
    with pytest.raises(ValidationError):
        ResidenceUpdate.model_validate({field: None})


def test_update_requires_date_and_precision_together() -> None:
    with pytest.raises(ValidationError):
        ResidenceUpdate.model_validate({"started_on": "2022-03-01"})


def test_update_accepts_complete_date_change() -> None:
    update = ResidenceUpdate.model_validate(
        {
            "started_on": "2022-03-15",
            "started_on_precision": "month",
        }
    )

    assert update.started_on == date(2022, 3, 15)
    assert update.started_on_precision == "month"


def test_update_rejects_year_precision() -> None:
    with pytest.raises(ValidationError):
        ResidenceUpdate.model_validate(
            {
                "ended_on": "2024-01-01",
                "ended_on_precision": "year",
            }
        )


def valid_overlap_confirmation() -> dict:
    return {
        "requested": {
            "country_code": "ES",
            "city_id": None,
            "started_on": "2023-01-01",
            "started_on_precision": "month",
            "ended_on": "2023-12-01",
            "ended_on_precision": "month",
        },
        "overlaps": [
            {
                "residence_id": str(uuid4()),
                "kind": "certain",
                "country_code": "PT",
                "city_id": 2267057,
                "started_on": "2020-01-01",
                "started_on_precision": "month",
                "ended_on": "2023-12-01",
                "ended_on_precision": "month",
            }
        ],
        "expected_target": None,
    }


def test_create_accepts_overlap_confirmation() -> None:
    payload = valid_overlap_confirmation()["requested"].copy()
    payload["overlap_confirmation"] = valid_overlap_confirmation()

    residence = ResidenceCreate.model_validate(payload)

    assert residence.overlap_confirmation is not None
    assert len(residence.overlap_confirmation.overlaps) == 1
    assert residence.overlap_confirmation.overlaps[0].kind == "certain"


def test_overlap_confirmation_rejects_year_precision() -> None:
    confirmation = valid_overlap_confirmation()
    confirmation["requested"]["started_on_precision"] = "year"

    payload = valid_residence_payload()
    payload["overlap_confirmation"] = confirmation

    with pytest.raises(ValidationError):
        ResidenceCreate.model_validate(payload)


def test_overlap_confirmation_rejects_invalid_overlap_kind() -> None:
    confirmation = valid_overlap_confirmation()
    confirmation["overlaps"][0]["kind"] = "unknown"

    payload = valid_residence_payload()
    payload["overlap_confirmation"] = confirmation

    with pytest.raises(ValidationError):
        ResidenceCreate.model_validate(payload)


def test_overlap_confirmation_rejects_extra_fields() -> None:
    confirmation = valid_overlap_confirmation()
    confirmation["unexpected"] = True

    payload = valid_residence_payload()
    payload["overlap_confirmation"] = confirmation

    with pytest.raises(ValidationError):
        ResidenceCreate.model_validate(payload)


def test_update_accepts_overlap_confirmation_with_changes() -> None:
    update = ResidenceUpdate.model_validate(
        {
            "city_id": None,
            "overlap_confirmation": valid_overlap_confirmation(),
        }
    )

    assert update.city_id is None
    assert update.overlap_confirmation is not None


def test_update_rejects_confirmation_without_changes() -> None:
    with pytest.raises(
        ValidationError,
        match="requires residence changes",
    ):
        ResidenceUpdate.model_validate(
            {
                "overlap_confirmation": valid_overlap_confirmation(),
            }
        )
