"""City visit API schemas."""

from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, field_validator, model_validator

from app.domain.visit_dates import (
    DatePrecision,
    validate_partial_visit_dates,
)


class CityVisitResponse(BaseModel):
    """Representation of an individual city visit."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    city_id: int
    city_name: str
    country_code: str
    country_name: str
    country_visit_id: UUID | None
    started_on: date | None
    ended_on: date | None
    created_at: datetime
    updated_at: datetime
    started_on_precision: DatePrecision | None
    ended_on_precision: DatePrecision | None


class CityVisitListResponse(BaseModel):
    """List of the authenticated user's city visits."""

    items: list[CityVisitResponse]
    total: int


class NewCountryVisit(BaseModel):
    """Country visit dates for an explicit joint creation."""

    model_config = ConfigDict(extra="forbid")

    started_on: date
    ended_on: date
    started_on_precision: DatePrecision | None = None
    ended_on_precision: DatePrecision | None = None

    @model_validator(mode="after")
    def validate_visit(self) -> "NewCountryVisit":
        if "started_on_precision" not in self.model_fields_set:
            self.started_on_precision = DatePrecision.DAY

        if "ended_on_precision" not in self.model_fields_set:
            self.ended_on_precision = DatePrecision.DAY

        self.started_on, self.ended_on = validate_partial_visit_dates(
            self.started_on,
            self.started_on_precision,
            self.ended_on,
            self.ended_on_precision,
        )

        return self


class CountryVisitDateState(BaseModel):
    """Exact date state used for expansion proposals and confirmations."""

    model_config = ConfigDict(extra="forbid")

    started_on: date
    started_on_precision: DatePrecision
    ended_on: date
    ended_on_precision: DatePrecision

    @model_validator(mode="after")
    def validate_dates(self) -> "CountryVisitDateState":
        self.started_on, self.ended_on = validate_partial_visit_dates(
            self.started_on,
            self.started_on_precision,
            self.ended_on,
            self.ended_on_precision,
        )
        return self


class CountryDateExpansionConfirmation(BaseModel):
    """Explicit approval of a previously presented date expansion."""

    model_config = ConfigDict(extra="forbid")

    expected: CountryVisitDateState
    proposed: CountryVisitDateState


class CityVisitCreate(BaseModel):
    """Data required to register a city visit."""

    model_config = ConfigDict(extra="forbid")

    city_id: int
    country_visit_id: UUID | None = None
    started_on: date
    ended_on: date
    started_on_precision: DatePrecision | None = None
    ended_on_precision: DatePrecision | None = None
    new_country_visit: NewCountryVisit | None = None
    country_date_expansion: CountryDateExpansionConfirmation | None = None

    @field_validator("city_id")
    @classmethod
    def validate_city_id(cls, value: int) -> int:
        if value <= 0:
            raise ValueError("City ID must be positive.")

        return value

    @model_validator(mode="after")
    def validate_visit(self) -> "CityVisitCreate":
        if self.country_visit_id is not None and self.new_country_visit is not None:
            raise ValueError("country_visit_id and new_country_visit cannot be provided together.")
        if self.started_on is not None and "started_on_precision" not in self.model_fields_set:
            self.started_on_precision = DatePrecision.DAY

        if self.ended_on is not None and "ended_on_precision" not in self.model_fields_set:
            self.ended_on_precision = DatePrecision.DAY

        if self.country_date_expansion is not None:
            if self.country_visit_id is None:
                raise ValueError("Country date expansion requires an existing country visit.")

            if self.new_country_visit is not None:
                raise ValueError("Country date expansion cannot be used with a new country visit.")

        self.started_on, self.ended_on = validate_partial_visit_dates(
            self.started_on,
            self.started_on_precision,
            self.ended_on,
            self.ended_on_precision,
        )

        return self


class CityVisitUpdate(BaseModel):
    """Fields that may be modified on an existing city visit."""

    model_config = ConfigDict(extra="forbid")

    city_id: int | None = None
    country_visit_id: UUID | None = None
    started_on: date | None = None
    ended_on: date | None = None
    started_on_precision: DatePrecision | None = None
    ended_on_precision: DatePrecision | None = None
    country_date_expansion: CountryDateExpansionConfirmation | None = None

    @field_validator("city_id")
    @classmethod
    def validate_city_id(cls, value: int | None) -> int:
        if value is None:
            raise ValueError("City ID cannot be null.")

        if value <= 0:
            raise ValueError("City ID must be positive.")

        return value

    @model_validator(mode="after")
    def validate_update(self) -> "CityVisitUpdate":
        if not self.model_fields_set:
            raise ValueError("At least one field must be provided.")

        if (
            self.country_date_expansion is not None
            and "country_visit_id" in self.model_fields_set
            and self.country_visit_id is None
        ):
            raise ValueError(
                "Cannot confirm country date expansion while removing the association."
            )
        return self


def test_city_visit_create_accepts_expansion_confirmation() -> None:
    payload = CityVisitCreate.model_validate(
        {
            "city_id": LISBON_ID,
            "started_on": "2025-06-12",
            "ended_on": "2025-06-18",
            "country_visit_id": "11111111-1111-4111-8111-111111111111",
            "country_date_expansion": {
                "expected": {
                    "started_on": "2025-06-10",
                    "started_on_precision": "day",
                    "ended_on": "2025-06-15",
                    "ended_on_precision": "day",
                },
                "proposed": {
                    "started_on": "2025-06-10",
                    "started_on_precision": "day",
                    "ended_on": "2025-06-18",
                    "ended_on_precision": "day",
                },
            },
        }
    )

    assert payload.country_date_expansion is not None
    assert payload.country_date_expansion.proposed.ended_on == date(2025, 6, 18)


def test_city_visit_create_rejects_expansion_without_country_visit() -> None:
    with pytest.raises(ValueError, match="requires an existing country visit"):
        CityVisitCreate.model_validate(
            {
                "city_id": LISBON_ID,
                "started_on": "2025-06-12",
                "ended_on": "2025-06-18",
                "country_date_expansion": {
                    "expected": {
                        "started_on": "2025-06-10",
                        "started_on_precision": "day",
                        "ended_on": "2025-06-15",
                        "ended_on_precision": "day",
                    },
                    "proposed": {
                        "started_on": "2025-06-10",
                        "started_on_precision": "day",
                        "ended_on": "2025-06-18",
                        "ended_on_precision": "day",
                    },
                },
            }
        )


def test_city_visit_update_rejects_expansion_and_disassociation() -> None:
    with pytest.raises(ValueError, match="removing the association"):
        CityVisitUpdate.model_validate(
            {
                "country_visit_id": None,
                "country_date_expansion": {
                    "expected": {
                        "started_on": "2025-06-10",
                        "started_on_precision": "day",
                        "ended_on": "2025-06-15",
                        "ended_on_precision": "day",
                    },
                    "proposed": {
                        "started_on": "2025-06-10",
                        "started_on_precision": "day",
                        "ended_on": "2025-06-18",
                        "ended_on_precision": "day",
                    },
                },
            }
        )
