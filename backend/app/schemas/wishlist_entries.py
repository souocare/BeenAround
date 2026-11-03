"""API schemas for global wishlist entries."""

from datetime import datetime
from uuid import UUID

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)


class WishlistEntryCreate(BaseModel):
    """Request to add a country or city to the global wishlist."""

    model_config = ConfigDict(extra="forbid")

    country_code: str | None = None
    city_id: int | None = Field(default=None, strict=True, gt=0)

    include_country: bool = False

    @field_validator("country_code")
    @classmethod
    def normalize_country_code(cls, value: str | None) -> str | None:
        """Normalize and validate an optional ISO alpha-2 country code."""

        if value is None:
            return None

        normalized = value.strip().upper()

        if len(normalized) != 2 or not normalized.isascii() or not normalized.isalpha():
            raise ValueError("Country code must contain exactly two ASCII letters.")

        return normalized

    @model_validator(mode="after")
    def validate_destination(self) -> "WishlistEntryCreate":
        """Require exactly one destination in the request."""

        has_country = self.country_code is not None
        has_city = self.city_id is not None

        if has_country == has_city:
            raise ValueError("Exactly one destination must be provided: country_code or city_id.")

        if self.include_country and not has_city:
            raise ValueError("include_country can only be used with a city.")

        return self


class WishlistEntryResponse(BaseModel):
    """A persisted global wishlist entry."""

    model_config = ConfigDict(from_attributes=True)

    id: UUID

    country_code: str | None
    city_id: int | None

    created_at: datetime
    updated_at: datetime


class WishlistEntryListResponse(BaseModel):
    """The authenticated user's global wishlist."""

    items: list[WishlistEntryResponse]
    total: int


class WishlistEntryCreateResponse(BaseModel):
    """Report which requested wishlist entries were created or already existed."""

    created: list[WishlistEntryResponse]
    existing: list[WishlistEntryResponse]
