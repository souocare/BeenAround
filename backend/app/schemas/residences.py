"""Historical residence API schemas."""

from datetime import date, datetime
from uuid import UUID

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)

from app.domain.residences import ResidenceOverlapKind, validate_residence_dates
from app.domain.visit_dates import DatePrecision


class ResidenceDateState(BaseModel):
    """Canonical date state of a historical residence."""

    model_config = ConfigDict(extra="forbid")

    started_on: date
    started_on_precision: DatePrecision
    ended_on: date
    ended_on_precision: DatePrecision

    @model_validator(mode="after")
    def validate_dates(self) -> "ResidenceDateState":
        self.started_on, self.ended_on = validate_residence_dates(
            started_on=self.started_on,
            started_on_precision=self.started_on_precision,
            ended_on=self.ended_on,
            ended_on_precision=self.ended_on_precision,
        )
        return self


class ResidenceRequestedState(ResidenceDateState):
    """Complete destination and date state requested by the user."""

    country_code: str
    city_id: int | None


class ResidenceOverlapState(ResidenceRequestedState):
    """Snapshot of an existing overlapping residence."""

    residence_id: UUID
    kind: ResidenceOverlapKind


class ResidenceTargetState(ResidenceRequestedState):
    """Expected original state of a residence being edited."""

    residence_id: UUID


class ResidenceOverlapConfirmation(BaseModel):
    """Explicit confirmation of a previously presented overlap proposal."""

    model_config = ConfigDict(extra="forbid")

    requested: ResidenceRequestedState
    overlaps: list[ResidenceOverlapState]
    expected_target: ResidenceTargetState | None = None


def normalize_residence_note(value: str | None) -> str | None:
    """Normalize an optional plain-text residence note."""

    if value is None:
        return None

    normalized = value.strip()

    return normalized or None


class ResidenceCreate(BaseModel):
    """Data required to register a historical residence."""

    model_config = ConfigDict(extra="forbid")

    country_code: str
    city_id: int | None = None

    started_on: date
    started_on_precision: DatePrecision

    ended_on: date
    ended_on_precision: DatePrecision
    note: str | None = Field(
        default=None,
        max_length=1000,
    )

    overlap_confirmation: ResidenceOverlapConfirmation | None = None

    @field_validator("country_code")
    @classmethod
    def validate_country_code(cls, value: str) -> str:
        normalized = value.strip().upper()

        if len(normalized) != 2 or not normalized.isalpha():
            raise ValueError("Country code must contain two letters.")

        return normalized

    @field_validator("city_id")
    @classmethod
    def validate_city_id(cls, value: int | None) -> int | None:
        if value is not None and value <= 0:
            raise ValueError("City ID must be positive.")

        return value

    @model_validator(mode="after")
    def validate_dates(self) -> "ResidenceCreate":
        self.started_on, self.ended_on = validate_residence_dates(
            started_on=self.started_on,
            started_on_precision=self.started_on_precision,
            ended_on=self.ended_on,
            ended_on_precision=self.ended_on_precision,
        )

        return self

    @field_validator("note")
    @classmethod
    def validate_note(cls, value: str | None) -> str | None:
        return normalize_residence_note(value)


class ResidenceUpdate(BaseModel):
    """Fields that may be changed on an existing residence."""

    model_config = ConfigDict(extra="forbid")

    country_code: str | None = None
    city_id: int | None = None

    started_on: date | None = None
    started_on_precision: DatePrecision | None = None

    ended_on: date | None = None
    ended_on_precision: DatePrecision | None = None
    note: str | None = Field(
        default=None,
        max_length=1000,
    )

    overlap_confirmation: ResidenceOverlapConfirmation | None = None

    @field_validator("country_code")
    @classmethod
    def validate_country_code(cls, value: str | None) -> str:
        if value is None:
            raise ValueError("Country code cannot be null.")

        normalized = value.strip().upper()

        if len(normalized) != 2 or not normalized.isalpha():
            raise ValueError("Country code must contain two letters.")

        return normalized

    @field_validator("city_id")
    @classmethod
    def validate_city_id(cls, value: int | None) -> int | None:
        if value is not None and value <= 0:
            raise ValueError("City ID must be positive.")

        return value

    @model_validator(mode="after")
    def validate_update(self) -> "ResidenceUpdate":
        fields = self.model_fields_set

        if not fields:
            raise ValueError("At least one field must be provided.")

        if fields == {"overlap_confirmation"}:
            raise ValueError("Overlap confirmation requires residence changes.")

        if "overlap_confirmation" in fields and not (fields - {"overlap_confirmation", "note"}):
            raise ValueError("Overlap confirmation requires destination or date changes.")

        for name in (
            "started_on",
            "started_on_precision",
            "ended_on",
            "ended_on_precision",
        ):
            if name in fields and getattr(self, name) is None:
                raise ValueError(f"{name} cannot be null.")

        for date_field in ("started_on", "ended_on"):
            precision_field = f"{date_field}_precision"

            if (date_field in fields) != (precision_field in fields):
                raise ValueError(f"{date_field} and {precision_field} must be provided together.")

        if "started_on_precision" in fields:
            if self.started_on_precision == DatePrecision.YEAR:
                raise ValueError("Residence start date requires day or month precision.")

        if "ended_on_precision" in fields:
            if self.ended_on_precision == DatePrecision.YEAR:
                raise ValueError("Residence end date requires day or month precision.")

        return self

    @field_validator("note")
    @classmethod
    def validate_note(cls, value: str | None) -> str | None:
        return normalize_residence_note(value)


class ResidenceResponse(BaseModel):
    """Representation of a historical residence."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID

    country_code: str
    city_id: int | None

    started_on: date
    started_on_precision: DatePrecision

    ended_on: date
    ended_on_precision: DatePrecision

    created_at: datetime
    updated_at: datetime
    note: str | None


class ResidenceListResponse(BaseModel):
    """List of the authenticated user's historical residences."""

    items: list[ResidenceResponse]
    total: int
