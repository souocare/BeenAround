"""Tests for global wishlist API schemas."""

from datetime import datetime
from uuid import uuid4

import pytest
from pydantic import ValidationError

from app.schemas.wishlist_entries import (
    WishlistEntryCreate,
    WishlistEntryCreateResponse,
    WishlistEntryListResponse,
    WishlistEntryResponse,
    WishlistEntryUpdate,
)


LISBON_ID = 2267057


def test_create_accepts_country() -> None:
    payload = WishlistEntryCreate.model_validate({"country_code": "PT"})

    assert payload.country_code == "PT"
    assert payload.city_id is None
    assert payload.include_country is False


def test_create_accepts_city() -> None:
    payload = WishlistEntryCreate.model_validate({"city_id": LISBON_ID})

    assert payload.country_code is None
    assert payload.city_id == LISBON_ID
    assert payload.include_country is False


def test_create_accepts_city_with_explicit_country() -> None:
    payload = WishlistEntryCreate.model_validate(
        {
            "city_id": LISBON_ID,
            "include_country": True,
        }
    )

    assert payload.city_id == LISBON_ID
    assert payload.include_country is True


def test_create_normalizes_country_code() -> None:
    payload = WishlistEntryCreate.model_validate({"country_code": " pt "})

    assert payload.country_code == "PT"


@pytest.mark.parametrize(
    "country_code",
    [
        "",
        "P",
        "PRT",
        "12",
        "P1",
        "日本",
    ],
)
def test_create_rejects_invalid_country_codes(
    country_code: str,
) -> None:
    with pytest.raises(ValidationError):
        WishlistEntryCreate.model_validate({"country_code": country_code})


@pytest.mark.parametrize(
    "city_id",
    [
        0,
        -1,
        "2267057",
        True,
        1.5,
    ],
)
def test_create_rejects_invalid_city_ids(city_id: object) -> None:
    with pytest.raises(ValidationError):
        WishlistEntryCreate.model_validate({"city_id": city_id})


def test_create_rejects_missing_destination() -> None:
    with pytest.raises(
        ValidationError,
        match="Exactly one destination",
    ):
        WishlistEntryCreate.model_validate({})


def test_create_rejects_both_destinations() -> None:
    with pytest.raises(
        ValidationError,
        match="Exactly one destination",
    ):
        WishlistEntryCreate.model_validate(
            {
                "country_code": "PT",
                "city_id": LISBON_ID,
            }
        )


def test_create_rejects_both_null_destinations() -> None:
    with pytest.raises(ValidationError):
        WishlistEntryCreate.model_validate(
            {
                "country_code": None,
                "city_id": None,
            }
        )


def test_create_rejects_country_with_include_country() -> None:
    with pytest.raises(
        ValidationError,
        match="include_country",
    ):
        WishlistEntryCreate.model_validate(
            {
                "country_code": "PT",
                "include_country": True,
            }
        )


def test_create_rejects_include_country_without_city() -> None:
    with pytest.raises(ValidationError):
        WishlistEntryCreate.model_validate({"include_country": True})


def test_create_rejects_unknown_fields() -> None:
    with pytest.raises(ValidationError):
        WishlistEntryCreate.model_validate(
            {
                "country_code": "PT",
                "notes": "I want to visit Portugal.",
            }
        )


def test_create_rejects_travel_dates() -> None:
    with pytest.raises(ValidationError):
        WishlistEntryCreate.model_validate(
            {
                "country_code": "PT",
                "started_on": "2027-01-01",
            }
        )


def test_response_serializes_country_entry() -> None:
    now = datetime(2026, 11, 3, 15, 0)

    response = WishlistEntryResponse(
        id=uuid4(),
        country_code="PT",
        city_id=None,
        created_at=now,
        updated_at=now,
        note=None,
    )

    data = response.model_dump(mode="json")

    assert data["country_code"] == "PT"
    assert data["city_id"] is None
    assert data["created_at"] == "2026-11-03T15:00:00"


def test_response_serializes_city_entry() -> None:
    now = datetime(2026, 11, 3, 15, 0)

    response = WishlistEntryResponse(
        id=uuid4(),
        country_code=None,
        city_id=LISBON_ID,
        created_at=now,
        updated_at=now,
        note=None,
    )

    data = response.model_dump(mode="json")

    assert data["country_code"] is None
    assert data["city_id"] == LISBON_ID


def test_list_response_contains_total() -> None:
    now = datetime(2026, 11, 3, 15, 0)

    entry = WishlistEntryResponse(
        id=uuid4(),
        country_code="PT",
        city_id=None,
        created_at=now,
        updated_at=now,
        note=None,
    )

    response = WishlistEntryListResponse(
        items=[entry],
        total=1,
    )

    assert response.total == 1
    assert len(response.items) == 1


def test_create_response_distinguishes_created_and_existing() -> None:
    now = datetime(2026, 11, 3, 15, 0)

    city = WishlistEntryResponse(
        id=uuid4(),
        country_code=None,
        city_id=LISBON_ID,
        created_at=now,
        updated_at=now,
        note=None,
    )

    country = WishlistEntryResponse(
        id=uuid4(),
        country_code="PT",
        city_id=None,
        created_at=now,
        updated_at=now,
        note=None,
    )

    response = WishlistEntryCreateResponse(
        created=[city],
        existing=[country],
    )

    assert len(response.created) == 1
    assert len(response.existing) == 1

    assert response.created[0].city_id == LISBON_ID
    assert response.existing[0].country_code == "PT"


def test_create_response_allows_no_new_entries() -> None:
    now = datetime(2026, 11, 3, 15, 0)

    existing = WishlistEntryResponse(
        id=uuid4(),
        country_code="PT",
        city_id=None,
        created_at=now,
        updated_at=now,
        note=None,
    )

    response = WishlistEntryCreateResponse(
        created=[],
        existing=[existing],
    )

    assert response.created == []
    assert len(response.existing) == 1


def test_create_accepts_optional_note() -> None:
    payload = WishlistEntryCreate.model_validate(
        {
            "country_code": "JP",
            "note": "Visit during cherry blossom season.",
        }
    )

    assert payload.note == "Visit during cherry blossom season."


def test_create_without_note_defaults_to_none() -> None:
    payload = WishlistEntryCreate.model_validate({"country_code": "JP"})

    assert payload.note is None


def test_create_normalizes_note_whitespace() -> None:
    payload = WishlistEntryCreate.model_validate(
        {
            "country_code": "JP",
            "note": "  Visit Kyoto  ",
        }
    )

    assert payload.note == "Visit Kyoto"


def test_create_normalizes_empty_note_to_none() -> None:
    payload = WishlistEntryCreate.model_validate(
        {
            "country_code": "JP",
            "note": "   ",
        }
    )

    assert payload.note is None


def test_create_rejects_note_over_1000_characters() -> None:
    with pytest.raises(ValidationError):
        WishlistEntryCreate.model_validate(
            {
                "country_code": "JP",
                "note": "A" * 1001,
            }
        )


def test_create_accepts_note_of_1000_characters() -> None:
    payload = WishlistEntryCreate.model_validate(
        {
            "country_code": "JP",
            "note": "A" * 1000,
        }
    )

    assert len(payload.note) == 1000


def test_update_accepts_note() -> None:
    payload = WishlistEntryUpdate.model_validate({"note": "New travel plans"})

    assert payload.note == "New travel plans"


def test_update_accepts_explicit_null() -> None:
    payload = WishlistEntryUpdate.model_validate({"note": None})

    assert payload.note is None


def test_update_rejects_empty_payload() -> None:
    with pytest.raises(ValidationError):
        WishlistEntryUpdate.model_validate({})


def test_update_rejects_destination_changes() -> None:
    with pytest.raises(ValidationError):
        WishlistEntryUpdate.model_validate(
            {
                "note": "Updated",
                "country_code": "PT",
            }
        )


def test_update_rejects_long_note() -> None:
    with pytest.raises(ValidationError):
        WishlistEntryUpdate.model_validate(
            {
                "note": "A" * 1001,
            }
        )


def test_update_normalizes_blank_note_to_none() -> None:
    payload = WishlistEntryUpdate.model_validate({"note": "   "})

    assert payload.note is None
