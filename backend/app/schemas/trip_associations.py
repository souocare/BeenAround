"""API contracts for Trip visit associations."""

from uuid import UUID

from pydantic import BaseModel, ConfigDict
from app.schemas.flights import FlightResponse


class TripCountryVisitCreate(BaseModel):
    """Associate an existing country visit with a Trip."""

    model_config = ConfigDict(extra="forbid")

    country_visit_id: UUID


class TripCityVisitCreate(BaseModel):
    """Associate an existing city visit with a Trip."""

    model_config = ConfigDict(extra="forbid")

    city_visit_id: UUID


class TripVisitAssociationResponse(BaseModel):
    """Representation of an existing Trip visit association."""

    trip_id: UUID
    visit_id: UUID


class TripFlightCreate(BaseModel):
    """Associate an existing personal flight with a Trip."""

    model_config = ConfigDict(extra="forbid")

    flight_id: UUID


class TripFlightAssociationResponse(BaseModel):
    """Representation of an existing Trip flight association."""

    trip_id: UUID
    flight_id: UUID


class TripFlightListResponse(BaseModel):
    """Flights explicitly associated with a Trip."""

    items: list[FlightResponse]
    total: int
