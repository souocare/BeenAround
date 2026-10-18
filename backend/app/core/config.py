from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parents[2]
PROJECT_DIR = BACKEND_DIR.parent
DATA_DIR = BACKEND_DIR / "data"


def default_database_url() -> str:
    return f"sqlite:///{DATA_DIR / 'beenaround.db'}"


class Settings(BaseSettings):
    app_name: str = "BeenAround"
    environment: str = "development"
    debug: bool = False

    # Authentication
    secret_key: str | None = None
    access_token_expire_minutes: int = 15
    session_idle_expire_days: int = 30

    database_url: str = default_database_url()

    csrf_allowed_origins: list[str] = []

    model_config = SettingsConfigDict(
        env_file=PROJECT_DIR / ".env",
        env_prefix="BEENAROUND_",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
