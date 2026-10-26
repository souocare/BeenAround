"""Tests for country and city visit date precision schemas."""

from datetime import date

import pytest
from pydantic import ValidationError

from app.domain.visit_dates import DatePrecision
from app.schemas.city_visits import CityVisitCreate, CityVisitUpdate
from app.schemas.country_visits import CountryVisitCreate, CountryVisitUpdate


@pytest.mark.parametrize(
    ("schema", "identifier"),
    [
        (CountryVisitCreate, {"country_code": "PT"}),
        (CityVisitCreate, {"city_id": 1}),
    ],
)
def test_create_without_dates(schema, identifier):
    payload = schema.model_validate(identifier)

    assert payload.started_on is None
    assert payload.started_on_precision is None
    assert payload.ended_on is None
    assert payload.ended_on_precision is None


@pytest.mark.parametrize(
    ("schema", "identifier"),
    [
        (CountryVisitCreate, {"country_code": "PT"}),
        (CityVisitCreate, {"city_id": 1}),
    ],
)
def test_create_with_exact_dates_defaults_to_day(schema, identifier):
    payload = schema.model_validate(
        {
            **identifier,
            "started_on": "2024-08-15",
            "ended_on": "2024-08-20",
        }
    )

    assert payload.started_on == date(2024, 8, 15)
    assert payload.started_on_precision == DatePrecision.DAY
    assert payload.ended_on == date(2024, 8, 20)
    assert payload.ended_on_precision == DatePrecision.DAY


@pytest.mark.parametrize(
    ("schema", "identifier"),
    [
        (CountryVisitCreate, {"country_code": "PT"}),
        (CityVisitCreate, {"city_id": 1}),
    ],
)
def test_create_normalizes_partial_dates(schema, identifier):
    payload = schema.model_validate(
        {
            **identifier,
            "started_on": "2024-08-15",
            "started_on_precision": "month",
            "ended_on": "2024-12-20",
            "ended_on_precision": "year",
        }
    )

    assert payload.started_on == date(2024, 8, 1)
    assert payload.started_on_precision == DatePrecision.MONTH
    assert payload.ended_on == date(2024, 1, 1)
    assert payload.ended_on_precision == DatePrecision.YEAR


@pytest.mark.parametrize(
    ("schema", "identifier"),
    [
        (CountryVisitCreate, {"country_code": "PT"}),
        (CityVisitCreate, {"city_id": 1}),
    ],
)
def test_create_rejects_precision_without_date(schema, identifier):
    with pytest.raises(ValidationError):
        schema.model_validate(
            {
                **identifier,
                "started_on_precision": "month",
            }
        )


@pytest.mark.parametrize(
    ("schema", "identifier"),
    [
        (CountryVisitCreate, {"country_code": "PT"}),
        (CityVisitCreate, {"city_id": 1}),
    ],
)
def test_create_rejects_explicit_null_precision_with_date(
    schema,
    identifier,
):
    with pytest.raises(ValidationError):
        schema.model_validate(
            {
                **identifier,
                "started_on": "2024-08-15",
                "started_on_precision": None,
            }
        )


@pytest.mark.parametrize(
    ("schema", "identifier"),
    [
        (CountryVisitCreate, {"country_code": "PT"}),
        (CityVisitCreate, {"city_id": 1}),
    ],
)
def test_create_rejects_impossible_date_range(schema, identifier):
    with pytest.raises(ValidationError):
        schema.model_validate(
            {
                **identifier,
                "started_on": "2024-09-01",
                "started_on_precision": "month",
                "ended_on": "2024-08-15",
                "ended_on_precision": "day",
            }
        )


@pytest.mark.parametrize(
    "schema",
    [CountryVisitUpdate, CityVisitUpdate],
)
def test_update_preserves_omitted_fields(schema):
    payload = schema.model_validate(
        {
            "started_on_precision": "month",
        }
    )

    changes = payload.model_dump(exclude_unset=True)

    assert changes == {
        "started_on_precision": DatePrecision.MONTH,
    }


@pytest.mark.parametrize(
    "schema",
    [CountryVisitUpdate, CityVisitUpdate],
)
def test_update_preserves_explicit_null(schema):
    payload = schema.model_validate(
        {
            "ended_on": None,
        }
    )

    changes = payload.model_dump(exclude_unset=True)

    assert changes == {
        "ended_on": None,
    }


@pytest.mark.parametrize(
    "schema",
    [CountryVisitUpdate, CityVisitUpdate],
)
def test_update_rejects_empty_payload(schema):
    with pytest.raises(ValidationError):
        schema.model_validate({})


@pytest.mark.parametrize(
    "schema",
    [CountryVisitUpdate, CityVisitUpdate],
)
def test_update_rejects_invalid_precision(schema):
    with pytest.raises(ValidationError):
        schema.model_validate(
            {
                "started_on_precision": "week",
            }
        )
