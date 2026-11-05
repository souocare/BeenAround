"""API contracts for Trip visit associations."""

from uuid import UUID

from pydantic import BaseModel, ConfigDict


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