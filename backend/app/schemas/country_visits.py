"""Country visit API schemas."""

from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class CountryVisitResponse(BaseModel):
    """Representation of an individual country visit."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    country_code: str
    started_on: date | None
    ended_on: date | None
    created_at: datetime
    updated_at: datetime


class CountryVisitListResponse(BaseModel):
    """List of the authenticated user's country visits."""

    items: list[CountryVisitResponse]
    total: int
