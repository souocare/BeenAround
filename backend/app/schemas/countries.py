"""Country catalog API schemas."""

from pydantic import BaseModel, ConfigDict


class CountryResponse(BaseModel):
    """Public country catalog representation."""

    model_config = ConfigDict(from_attributes=True)

    code: str
    name: str
    alpha3_code: str
    continent: str


class CountryListResponse(BaseModel):
    """Complete country catalog response."""

    items: list[CountryResponse]
    total: int
