"""Pydantic contracts for personal flight records."""

from datetime import date, datetime, time
from uuid import UUID

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)

from app.domain.flights import (
    CabinClass,
    FlightStatus,
    REQUIRED_FLIGHT_FIELDS,
    normalize_optional_text,
    validate_flight_consistency,
    validate_local_time,
)
from app.services.flight_time import LocalTimeStatus

TEXT_LIMITS = {
    "airline_name": 200,
    "flight_number": 20,
    "aircraft_type": 120,
    "aircraft_registration": 30,
    "seat": 20,
    "notes": 10000,
}

UPPERCASE_FIELDS = frozenset(
    {
        "flight_number",
        "aircraft_registration",
        "seat",
    }
)


class FlightFields(BaseModel):
    """Shared optional details and their normalization."""

    model_config = ConfigDict(extra="forbid")

    airline_id: int | None = Field(default=None, gt=0)
    airline_name: str | None = None
    flight_number: str | None = None

    departure_time: time | None = None
    arrival_on: date | None = None
    arrival_time: time | None = None

    aircraft_type: str | None = None
    aircraft_registration: str | None = None
    seat: str | None = None
    cabin_class: CabinClass | None = None

    notes: str | None = None

    @field_validator(*TEXT_LIMITS.keys())
    @classmethod
    def normalize_text_fields(
        cls,
        value: str | None,
        info,
    ) -> str | None:
        return normalize_optional_text(
            value,
            max_length=TEXT_LIMITS[info.field_name],
            uppercase=info.field_name in UPPERCASE_FIELDS,
        )

    @field_validator("departure_time", "arrival_time")
    @classmethod
    def validate_local_times(
        cls,
        value: time | None,
    ) -> time | None:
        return validate_local_time(value)


class FlightCreate(FlightFields):
    """Payload for creating a personal flight."""

    departure_airport_id: int = Field(gt=0)
    arrival_airport_id: int = Field(gt=0)

    departure_on: date
    status: FlightStatus

    @model_validator(mode="after")
    def validate_flight(self) -> "FlightCreate":
        validate_flight_consistency(
            departure_airport_id=self.departure_airport_id,
            arrival_airport_id=self.arrival_airport_id,
            airline_id=self.airline_id,
            airline_name=self.airline_name,
            departure_on=self.departure_on,
            departure_time=self.departure_time,
            arrival_on=self.arrival_on,
            arrival_time=self.arrival_time,
            status=self.status,
        )

        return self


class FlightUpdate(FlightFields):
    """Partial update of an existing personal flight."""

    departure_airport_id: int | None = Field(default=None, gt=0)
    arrival_airport_id: int | None = Field(default=None, gt=0)

    departure_on: date | None = None
    status: FlightStatus | None = None

    @model_validator(mode="after")
    def validate_patch(self) -> "FlightUpdate":
        if not self.model_fields_set:
            raise ValueError("At least one field must be provided.")

        for field in REQUIRED_FLIGHT_FIELDS:
            if field in self.model_fields_set:
                if getattr(self, field) is None:
                    raise ValueError(f"{field} cannot be null.")

        return self


class FlightResponse(BaseModel):
    """Representation of a persisted personal flight."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID

    departure_airport_id: int
    arrival_airport_id: int

    airline_id: int | None
    airline_name: str | None
    flight_number: str | None

    departure_on: date
    departure_time: time | None
    arrival_on: date | None
    arrival_time: time | None

    status: FlightStatus

    aircraft_type: str | None
    aircraft_registration: str | None
    seat: str | None
    cabin_class: CabinClass | None
    notes: str | None

    created_at: datetime
    updated_at: datetime


class FlightListResponse(BaseModel):
    """Paginated list of the authenticated user's flights."""

    items: list[FlightResponse]
    total: int
    limit: int
    offset: int

class FlightLocalTimeResponse(BaseModel):
    """Timezone resolution for one airport-local flight time."""

    status: LocalTimeStatus
    utc_offset_minutes: int | None


class FlightTimingResponse(BaseModel):
    """Calculated timing information for a flight segment."""

    departure: FlightLocalTimeResponse
    arrival: FlightLocalTimeResponse
    duration_minutes: int | None


class FlightDetailResponse(FlightResponse):
    """Detailed flight representation with calculated timing."""

    timing: FlightTimingResponse
