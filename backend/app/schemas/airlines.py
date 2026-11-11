"""Airline catalog API schemas."""

from pydantic import BaseModel, ConfigDict


class AirlineResponse(BaseModel):
    """Public representation of a catalog airline."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str

    iata_code: str | None
    icao_code: str | None

    callsign: str | None
    country_name: str | None


class AirlineListResponse(BaseModel):
    """Paginated airline search response."""

    items: list[AirlineResponse]
    total: int
    limit: int
    offset: int
