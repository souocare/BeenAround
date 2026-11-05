"""API schemas for user-owned Trips."""

from datetime import date, datetime
from uuid import UUID

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)

from app.domain.trip_dates import validate_trip_dates
from app.domain.visit_dates import DatePrecision


class TripResponse(BaseModel):
    """Representation of a persisted Trip."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    description: str | None

    started_on: date | None
    started_on_precision: DatePrecision | None

    ended_on: date | None
    ended_on_precision: DatePrecision | None

    created_at: datetime
    updated_at: datetime


class TripListResponse(BaseModel):
    """List of the authenticated user's Trips."""

    items: list[TripResponse]
    total: int


class TripCreate(BaseModel):
    """Data required to create a Trip."""

    model_config = ConfigDict(extra="forbid")

    name: str = Field(max_length=160)

    description: str | None = Field(
        default=None,
        max_length=5000,
    )

    started_on: date | None = None
    started_on_precision: DatePrecision | None = None

    ended_on: date | None = None
    ended_on_precision: DatePrecision | None = None

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        """Require a non-empty Trip name."""

        normalized = value.strip()

        if not normalized:
            raise ValueError("Trip name cannot be empty.")

        return normalized

    @field_validator("description")
    @classmethod
    def normalize_description(
        cls,
        value: str | None,
    ) -> str | None:
        """Normalize optional descriptions."""

        if value is None:
            return None

        return value.strip() or None

    @model_validator(mode="after")
    def validate_dates(self) -> "TripCreate":
        """Validate and normalize optional Trip dates."""

        if self.started_on is not None and "started_on_precision" not in self.model_fields_set:
            self.started_on_precision = DatePrecision.DAY

        if self.ended_on is not None and "ended_on_precision" not in self.model_fields_set:
            self.ended_on_precision = DatePrecision.DAY

        self.started_on, self.ended_on = validate_trip_dates(
            self.started_on,
            self.started_on_precision,
            self.ended_on,
            self.ended_on_precision,
        )

        return self


class TripUpdate(BaseModel):
    """Fields that may be modified on an existing Trip."""

    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(
        default=None,
        max_length=160,
    )

    description: str | None = Field(
        default=None,
        max_length=5000,
    )

    started_on: date | None = None
    started_on_precision: DatePrecision | None = None

    ended_on: date | None = None
    ended_on_precision: DatePrecision | None = None

    @field_validator("name")
    @classmethod
    def validate_name(
        cls,
        value: str | None,
    ) -> str:
        """Prevent clearing the required Trip name."""

        if value is None:
            raise ValueError("Trip name cannot be null.")

        normalized = value.strip()

        if not normalized:
            raise ValueError("Trip name cannot be empty.")

        return normalized

    @field_validator("description")
    @classmethod
    def normalize_description(
        cls,
        value: str | None,
    ) -> str | None:
        if value is None:
            return None

        return value.strip() or None

    @model_validator(mode="after")
    def validate_update(self) -> "TripUpdate":
        """Reject empty PATCH requests."""

        if not self.model_fields_set:
            raise ValueError("At least one field must be provided.")

        return self
