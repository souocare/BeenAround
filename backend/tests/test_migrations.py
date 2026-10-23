from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect


def test_initial_migration_creates_alembic_version_table(
    tmp_path: Path,
    monkeypatch,
) -> None:
    database_path = tmp_path / "migration_test.db"

    monkeypatch.setenv(
        "BEENAROUND_DATABASE_URL",
        f"sqlite:///{database_path}",
    )

    from app.core.config import get_settings

    get_settings.cache_clear()

    try:
        backend_dir = Path(__file__).resolve().parents[1]

        config = Config(str(backend_dir / "alembic.ini"))
        config.set_main_option("script_location", str(backend_dir / "migrations"))

        command.upgrade(config, "head")

        engine = create_engine(f"sqlite:///{database_path}")

        try:
            tables = inspect(engine).get_table_names()
            assert "alembic_version" in tables
            assert "countries" in tables
            assert "country_visits" in tables
            assert "cities" in tables
        finally:
            engine.dispose()
    finally:
        get_settings.cache_clear()
