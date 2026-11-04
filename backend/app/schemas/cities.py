"""City catalog API schemas."""

from pydantic import BaseModel, ConfigDict
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field


class CityResponse(BaseModel):
    """Public city catalog representation."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    ascii_name: str | None
    country_code: str
    country_name: str
    latitude: float
    longitude: float
    population: int | None
    feature_code: str


class CityListResponse(BaseModel):
    """Paginated city catalog response."""

    items: list[CityResponse]
    total: int
    limit: int
    offset: int


class CountryCityCountResponse(BaseModel):
    """Country and its number of catalog cities."""

    country_code: str
    country_name: str
    city_count: int


class CountryCityCountListResponse(BaseModel):
    """Country city counts response."""

    items: list[CountryCityCountResponse]


PositiveCityId = Annotated[int, Field(strict=True, gt=0)]


class CityResolveRequest(BaseModel):
    """Resolve a bounded list of city catalog IDs."""

    city_ids: list[PositiveCityId] = Field(max_length=200)


class CityResolveResponse(BaseModel):
    """Resolved city catalog entries in the requested order."""

    items: list[CityResponse]
