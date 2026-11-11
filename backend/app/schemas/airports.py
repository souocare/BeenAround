"""Airport catalog API schemas."""

from pydantic import BaseModel, ConfigDict


class AirportResponse(BaseModel):
    """Public representation of a catalog airport."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    ident: str
    iata_code: str | None
    icao_code: str | None
    name: str
    municipality: str | None

    source_country_code: str | None
    country_code: str | None
    country_name: str | None

    latitude: float | None
    longitude: float | None

    type: str
    scheduled_service: bool


class AirportListResponse(BaseModel):
    """Paginated airport search results."""

    items: list[AirportResponse]
    total: int
    limit: int
    offset: int
