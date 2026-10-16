from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parents[2]
PROJECT_DIR = BACKEND_DIR.parent


class Settings(BaseSettings):
    app_name: str = "BeenAround"
    environment: str = "development"
    debug: bool = False

    database_url: str = "sqlite:///./data/beenaround.db"

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
