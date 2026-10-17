from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


class SetupStatusResponse(BaseModel):
    setup_required: bool


class SetupRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    username: str = Field(min_length=3, max_length=32, pattern=r"^[a-z0-9_]+$")
    email: str | None = Field(default=None, max_length=320)
    display_name: str = Field(min_length=1, max_length=100)
    password: str = Field(min_length=12, max_length=1024)

    @field_validator("username", mode="before")
    @classmethod
    def normalize_username(cls, value: object) -> object:
        if isinstance(value, str):
            return value.strip().lower()
        return value

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str | None) -> str | None:
        if value is None:
            return None

        normalized = value.strip().lower()

        if not normalized:
            return None

        if "@" not in normalized:
            raise ValueError("Invalid email address.")

        local, domain = normalized.rsplit("@", 1)

        if not local or not domain or "." not in domain:
            raise ValueError("Invalid email address.")

        return normalized

    @field_validator("display_name")
    @classmethod
    def normalize_display_name(cls, value: str) -> str:
        normalized = value.strip()

        if not normalized:
            raise ValueError("Display name cannot be empty.")

        return normalized


class SetupResponse(BaseModel):
    id: UUID
    username: str
    display_name: str
    is_admin: bool

    model_config = ConfigDict(from_attributes=True)
