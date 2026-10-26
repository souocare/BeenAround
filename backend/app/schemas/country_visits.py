"""Country visit API schemas."""

from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, field_validator, model_validator
from app.domain.visit_dates import (
    DatePrecision,
    validate_partial_visit_dates,
)


def normalize_country_code(value: str) -> str:
    """Normalize and validate an ISO alpha-2 country code."""
    code = value.strip().upper()

    if len(code) != 2 or not code.isascii() or not code.isalpha():
        raise ValueError("Country code must be a valid ISO alpha-2 code.")

    return code


class CountryVisitResponse(BaseModel):
    """Representation of an individual country visit."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    country_code: str
    started_on: date | None
    ended_on: date | None
    created_at: datetime
    updated_at: datetime
    started_on_precision: DatePrecision | None
    ended_on_precision: DatePrecision | None


class CountryVisitListResponse(BaseModel):
    """List of the authenticated user's country visits."""

    items: list[CountryVisitResponse]
    total: int


class CountryVisitCreate(BaseModel):
    """Data required to register a country visit."""

    model_config = ConfigDict(extra="forbid")

    country_code: str
    started_on: date | None = None
    ended_on: date | None = None
    started_on_precision: DatePrecision | None = None
    ended_on_precision: DatePrecision | None = None

    @field_validator("country_code")
    @classmethod
    def validate_country_code(cls, value: str) -> str:
        return normalize_country_code(value)

    @model_validator(mode="after")
    def validate_visit(self) -> "CountryVisitCreate":
        if self.started_on is not None and "started_on_precision" not in self.model_fields_set:
            self.started_on_precision = DatePrecision.DAY

        if self.ended_on is not None and "ended_on_precision" not in self.model_fields_set:
            self.ended_on_precision = DatePrecision.DAY

        self.started_on, self.ended_on = validate_partial_visit_dates(
            self.started_on,
            self.started_on_precision,
            self.ended_on,
            self.ended_on_precision,
        )

        return self


class CountryVisitUpdate(BaseModel):
    """Fields that may be modified on an existing country visit."""

    model_config = ConfigDict(extra="forbid")

    country_code: str | None = None
    started_on: date | None = None
    ended_on: date | None = None
    started_on_precision: DatePrecision | None = None
    ended_on_precision: DatePrecision | None = None

    @field_validator("country_code")
    @classmethod
    def validate_country_code(cls, value: str | None) -> str:
        if value is None:
            raise ValueError("Country code cannot be null.")

        return normalize_country_code(value)

    @model_validator(mode="after")
    def validate_update(self) -> "CountryVisitUpdate":
        if not self.model_fields_set:
            raise ValueError("At least one field must be provided.")

        return self
