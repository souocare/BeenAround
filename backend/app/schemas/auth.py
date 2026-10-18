from pydantic import BaseModel, ConfigDict, Field

from app.schemas.setup import SetupResponse


class LoginRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    login: str = Field(min_length=1, max_length=320)
    password: str = Field(min_length=1, max_length=1024)


class LoginResponse(BaseModel):
    user: SetupResponse
