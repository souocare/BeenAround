"""Validation tests for Trip API schemas."""

from datetime import date

import pytest
from pydantic import ValidationError

from app.domain.visit_dates import DatePrecision
from app.schemas.trips import TripCreate, TripUpdate


def test_create_trip_with_name_only() -> None:
    payload = TripCreate(name="Japan 2027")

    assert payload.name == "Japan 2027"
    assert payload.description is None
    assert payload.started_on is None
    assert payload.ended_on is None


def test_create_normalizes_name_and_description() -> None:
    payload = TripCreate(
        name="  Japan 2027  ",
        description="  Spring holiday  ",
    )

    assert payload.name == "Japan 2027"
    assert payload.description == "Spring holiday"


def test_create_normalizes_empty_description() -> None:
    payload = TripCreate(
        name="Japan",
        description="   ",
    )

    assert payload.description is None


@pytest.mark.parametrize(
    "name",
    [
        "",
        " ",
        "   ",
    ],
)
def test_create_rejects_blank_name(name: str) -> None:
    with pytest.raises(ValidationError):
        TripCreate(name=name)


def test_create_rejects_missing_name() -> None:
    with pytest.raises(ValidationError):
        TripCreate()


def test_create_rejects_name_too_long() -> None:
    with pytest.raises(ValidationError):
        TripCreate(name="A" * 161)


def test_create_rejects_description_too_long() -> None:
    with pytest.raises(ValidationError):
        TripCreate(
            name="Japan",
            description="A" * 5001,
        )


def test_create_rejects_unknown_fields() -> None:
    with pytest.raises(ValidationError):
        TripCreate.model_validate(
            {
                "name": "Japan",
                "user_id": "invalid",
            }
        )


def test_create_defaults_to_day_precision() -> None:
    payload = TripCreate(
        name="Japan",
        started_on=date(2027, 4, 10),
        ended_on=date(2027, 4, 20),
    )

    assert payload.started_on_precision == DatePrecision.DAY
    assert payload.ended_on_precision == DatePrecision.DAY


def test_create_normalizes_month_precision() -> None:
    payload = TripCreate(
        name="Japan",
        started_on=date(2027, 4, 15),
        started_on_precision=DatePrecision.MONTH,
    )

    assert payload.started_on == date(2027, 4, 1)
    assert payload.started_on_precision == DatePrecision.MONTH


def test_create_normalizes_year_precision() -> None:
    payload = TripCreate(
        name="Japan",
        started_on=date(2027, 8, 20),
        started_on_precision=DatePrecision.YEAR,
    )

    assert payload.started_on == date(2027, 1, 1)
    assert payload.started_on_precision == DatePrecision.YEAR


def test_create_accepts_only_end_date() -> None:
    payload = TripCreate(
        name="Japan",
        ended_on=date(2027, 4, 20),
    )

    assert payload.started_on is None
    assert payload.ended_on == date(2027, 4, 20)


def test_create_rejects_invalid_date_range() -> None:
    with pytest.raises(ValidationError):
        TripCreate(
            name="Japan",
            started_on=date(2027, 5, 10),
            ended_on=date(2027, 4, 10),
        )


def test_create_accepts_overlapping_partial_dates() -> None:
    payload = TripCreate(
        name="Japan",
        started_on=date(2027, 4, 20),
        started_on_precision=DatePrecision.DAY,
        ended_on=date(2027, 4, 1),
        ended_on_precision=DatePrecision.MONTH,
    )

    assert payload.started_on == date(2027, 4, 20)
    assert payload.ended_on == date(2027, 4, 1)


@pytest.mark.parametrize(
    "payload",
    [
        {
            "started_on_precision": "day",
        },
        {
            "ended_on_precision": "month",
        },
        {
            "started_on": "2027-04-10",
            "started_on_precision": None,
        },
        {
            "ended_on": "2027-04-20",
            "ended_on_precision": None,
        },
        {
            "started_on": "2027-04-10",
            "started_on_precision": "invalid",
        },
    ],
)
def test_create_rejects_invalid_date_precision(
    payload: dict,
) -> None:
    with pytest.raises(ValidationError):
        TripCreate.model_validate(
            {
                "name": "Japan",
                **payload,
            }
        )


def test_update_accepts_name_only() -> None:
    payload = TripUpdate(name="Updated Japan")

    assert payload.model_dump(exclude_unset=True) == {
        "name": "Updated Japan",
    }


def test_update_accepts_description_removal() -> None:
    payload = TripUpdate(description=None)

    assert payload.model_dump(exclude_unset=True) == {
        "description": None,
    }


def test_update_accepts_date_removal() -> None:
    payload = TripUpdate(started_on=None)

    assert payload.model_dump(exclude_unset=True) == {
        "started_on": None,
    }


def test_update_accepts_precision_change() -> None:
    payload = TripUpdate(
        started_on_precision=DatePrecision.YEAR,
    )

    assert payload.started_on_precision == DatePrecision.YEAR


@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"name": None},
        {"name": ""},
        {"name": "   "},
        {"name": "A" * 161},
        {"description": "A" * 5001},
        {"unknown_field": "value"},
    ],
)
def test_update_rejects_invalid_payload(
    payload: dict,
) -> None:
    with pytest.raises(ValidationError):
        TripUpdate.model_validate(payload)