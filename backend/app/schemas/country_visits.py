"""Country visit API schemas."""

from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, model_validator


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


class CountryVisitCreate(BaseModel):
    """Data required to register a country visit."""

    model_config = ConfigDict(extra="forbid")

    country_code: str
    started_on: date | None = None
    ended_on: date | None = None

    @model_validator(mode="after")
    def validate_visit(self) -> "CountryVisitCreate":
        """Normalize the country code and validate visit dates."""

        self.country_code = self.country_code.strip().upper()

        if len(self.country_code) != 2 or not self.country_code.isalpha():
            raise ValueError("Country code must be a valid ISO alpha-2 code.")

        if self.ended_on is not None:
            if self.started_on is None:
                raise ValueError("End date requires a start date.")

            if self.ended_on < self.started_on:
                raise ValueError("End date cannot be earlier than start date.")

        return self
