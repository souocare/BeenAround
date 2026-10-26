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


class CityVisitCreate(BaseModel):
    """Data required to register a city visit."""

    model_config = ConfigDict(extra="forbid")

    city_id: int
    started_on: date | None = None
    ended_on: date | None = None
    started_on_precision: DatePrecision | None = None
    ended_on_precision: DatePrecision | None = None

    @field_validator("city_id")
    @classmethod
    def validate_city_id(cls, value: int) -> int:
        if value <= 0:
            raise ValueError("City ID must be positive.")

        return value

    @model_validator(mode="after")
    def validate_visit(self) -> "CityVisitCreate":
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


class CityVisitUpdate(BaseModel):
    """Fields that may be modified on an existing city visit."""

    model_config = ConfigDict(extra="forbid")

    city_id: int | None = None
    started_on: date | None = None
    ended_on: date | None = None
    started_on_precision: DatePrecision | None = None
    ended_on_precision: DatePrecision | None = None

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

        return self
