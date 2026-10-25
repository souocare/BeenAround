from pathlib import Path
from uuid import uuid4

import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.exc import IntegrityError


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


@pytest.fixture
def migration_config(tmp_path: Path, monkeypatch):
    """Configure Alembic against an isolated SQLite database."""

    database_path = tmp_path / "visit_precision_migration.db"
    database_url = f"sqlite:///{database_path}"

    monkeypatch.setenv("BEENAROUND_DATABASE_URL", database_url)

    from app.core.config import get_settings

    get_settings.cache_clear()

    backend_dir = Path(__file__).resolve().parents[1]

    config = Config(str(backend_dir / "alembic.ini"))
    config.set_main_option(
        "script_location",
        str(backend_dir / "migrations"),
    )

    try:
        yield config, database_url
    finally:
        get_settings.cache_clear()


def test_visit_precision_migration_preserves_existing_visits(
    migration_config,
) -> None:
    """Existing visits retain their dates and receive day precision."""

    config, database_url = migration_config

    command.upgrade(config, "644e0de73360")

    engine = create_engine(database_url)

    user_id = uuid4().hex
    country_visit_id = uuid4().hex
    city_visit_id = uuid4().hex

    try:
        with engine.begin() as connection:
            # Use existing catalog records created by the migrations.
            country = connection.execute(
                text("SELECT code FROM countries LIMIT 1")
            ).scalar_one_or_none()

            assert country is not None

            city_id = 9_000_001

            connection.execute(
                text(
                    """
                    INSERT INTO cities (
                        id,
                        country_code,
                        name,
                        ascii_name,
                        latitude,
                        longitude,
                        population,
                        feature_code
                    )
                    VALUES (
                        :id,
                        :country_code,
                        :name,
                        :ascii_name,
                        :latitude,
                        :longitude,
                        :population,
                        :feature_code
                    )
                    """
                ),
                {
                    "id": city_id,
                    "country_code": country,
                    "name": "Migration Test City",
                    "ascii_name": "Migration Test City",
                    "latitude": 38.72,
                    "longitude": -9.14,
                    "population": None,
                    "feature_code": "PPL",
                },
            )

            connection.execute(
                text(
                    """
                    INSERT INTO users (
                        id,
                        username,
                        email,
                        display_name,
                        password_hash
                    )
                    VALUES (
                        :id,
                        :username,
                        :email,
                        :display_name,
                        :password_hash
                    )
                    """
                ),
                {
                    "id": user_id,
                    "username": "migration_user",
                    "email": "migration@example.test",
                    "display_name": "Migration User",
                    "password_hash": "test_hash",
                },
            )

            connection.execute(
                text(
                    """
                    INSERT INTO country_visits (
                        id,
                        user_id,
                        country_code,
                        started_on,
                        ended_on
                    )
                    VALUES (
                        :id,
                        :user_id,
                        :country_code,
                        :started_on,
                        :ended_on
                    )
                    """
                ),
                {
                    "id": country_visit_id,
                    "user_id": user_id,
                    "country_code": country,
                    "started_on": "2024-08-15",
                    "ended_on": "2024-08-20",
                },
            )

            connection.execute(
                text(
                    """
                    INSERT INTO city_visits (
                        id,
                        user_id,
                        city_id,
                        started_on,
                        ended_on
                    )
                    VALUES (
                        :id,
                        :user_id,
                        :city_id,
                        :started_on,
                        :ended_on
                    )
                    """
                ),
                {
                    "id": city_visit_id,
                    "user_id": user_id,
                    "city_id": city_id,
                    "started_on": None,
                    "ended_on": None,
                },
            )

        command.upgrade(config, "4bd62fcb5448")

        with engine.connect() as connection:
            country_visit = connection.execute(
                text(
                    """
                    SELECT
                        started_on,
                        started_on_precision,
                        ended_on,
                        ended_on_precision
                    FROM country_visits
                    WHERE id = :id
                    """
                ),
                {"id": country_visit_id},
            ).one()

            assert country_visit.started_on == "2024-08-15"
            assert country_visit.started_on_precision == "day"
            assert country_visit.ended_on == "2024-08-20"
            assert country_visit.ended_on_precision == "day"

            city_visit = connection.execute(
                text(
                    """
                    SELECT
                        started_on,
                        started_on_precision,
                        ended_on,
                        ended_on_precision
                    FROM city_visits
                    WHERE id = :id
                    """
                ),
                {"id": city_visit_id},
            ).one()

            assert city_visit.started_on is None
            assert city_visit.started_on_precision is None
            assert city_visit.ended_on is None
            assert city_visit.ended_on_precision is None

    finally:
        engine.dispose()


def test_visit_precision_migration_creates_expected_constraints(
    migration_config,
) -> None:
    """Both visit tables enforce temporal precision at database level."""

    config, database_url = migration_config

    command.upgrade(config, "head")

    engine = create_engine(database_url)

    try:
        inspector = inspect(engine)

        for table in ("country_visits", "city_visits"):
            columns = {column["name"] for column in inspector.get_columns(table)}

            assert "started_on_precision" in columns
            assert "ended_on_precision" in columns

            constraints = {
                constraint["name"] for constraint in inspector.get_check_constraints(table)
            }

            assert f"ck_{table}_start_precision" in constraints
            assert f"ck_{table}_end_precision" in constraints
            assert f"ck_{table}_valid_dates" in constraints

    finally:
        engine.dispose()


@pytest.mark.parametrize(
    ("started_on", "started_precision", "ended_on", "ended_precision", "valid"),
    [
        ("2024-08-15", "day", "2024-08-20", "day", True),
        ("2024-08-01", "month", "2024-08-15", "day", True),
        ("2024-08-20", "day", "2024-08-01", "month", True),
        ("2024-01-01", "year", "2024-03-01", "month", True),
        ("2024-09-01", "month", "2024-08-15", "day", False),
        ("2025-01-01", "year", "2024-12-01", "month", False),
        ("2024-08-15", "month", None, None, False),
        ("2024-08-15", None, None, None, False),
        (None, "day", None, None, False),
        (None, None, "2024-08-15", "day", False),
        (None, None, None, None, True),
    ],
)
def test_visit_precision_constraints_enforce_valid_ranges(
    migration_config,
    started_on,
    started_precision,
    ended_on,
    ended_precision,
    valid,
) -> None:
    """SQLite must reject inconsistent or impossible partial-date ranges."""

    config, database_url = migration_config

    command.upgrade(config, "head")

    engine = create_engine(database_url)

    try:
        with engine.begin() as connection:
            country_code = connection.execute(
                text("SELECT code FROM countries LIMIT 1")
            ).scalar_one()

            user_id = uuid4().hex

            connection.execute(
                text(
                    """
                    INSERT INTO users (
                        id,
                        username,
                        display_name,
                        password_hash
                    )
                    VALUES (
                        :id,
                        :username,
                        :display_name,
                        :password_hash
                    )
                    """
                ),
                {
                    "id": user_id,
                    "username": f"user_{user_id[:12]}",
                    "display_name": "Constraint Test User",
                    "password_hash": "test_hash",
                },
            )

        parameters = {
            "id": uuid4().hex,
            "user_id": user_id,
            "country_code": country_code,
            "started_on": started_on,
            "started_on_precision": started_precision,
            "ended_on": ended_on,
            "ended_on_precision": ended_precision,
        }

        statement = text(
            """
            INSERT INTO country_visits (
                id,
                user_id,
                country_code,
                started_on,
                started_on_precision,
                ended_on,
                ended_on_precision
            )
            VALUES (
                :id,
                :user_id,
                :country_code,
                :started_on,
                :started_on_precision,
                :ended_on,
                :ended_on_precision
            )
            """
        )

        if valid:
            with engine.begin() as connection:
                connection.execute(statement, parameters)
        else:
            with pytest.raises(IntegrityError):
                with engine.begin() as connection:
                    connection.execute(statement, parameters)

    finally:
        engine.dispose()


def test_visit_precision_migration_preserves_foreign_keys_and_indexes(
    migration_config,
) -> None:
    """Rebuilding visit tables must preserve foreign keys and indexes."""

    config, database_url = migration_config

    command.upgrade(config, "head")

    engine = create_engine(database_url)

    try:
        inspector = inspect(engine)

        expected = {
            "country_visits": {
                "foreign_keys": {
                    ("user_id", "users"),
                    ("country_code", "countries"),
                },
                "index": "ix_country_visits_user_country",
            },
            "city_visits": {
                "foreign_keys": {
                    ("user_id", "users"),
                    ("city_id", "cities"),
                },
                "index": "ix_city_visits_user_city",
            },
        }

        for table, requirements in expected.items():
            foreign_keys = {
                (
                    tuple(foreign_key["constrained_columns"])[0],
                    foreign_key["referred_table"],
                )
                for foreign_key in inspector.get_foreign_keys(table)
            }

            assert requirements["foreign_keys"] <= foreign_keys

            indexes = {index["name"] for index in inspector.get_indexes(table)}

            assert requirements["index"] in indexes

    finally:
        engine.dispose()


def test_visit_precision_migration_downgrade_restores_previous_schema(
    migration_config,
) -> None:
    """Downgrade must restore the original visit table structure."""

    config, database_url = migration_config

    command.upgrade(config, "head")

    engine = create_engine(database_url)

    try:
        command.downgrade(config, "644e0de73360")

        inspector = inspect(engine)

        for table in ("country_visits", "city_visits"):
            columns = {column["name"] for column in inspector.get_columns(table)}

            assert "started_on" in columns
            assert "ended_on" in columns

            assert "started_on_precision" not in columns
            assert "ended_on_precision" not in columns

            constraints = {
                constraint["name"] for constraint in inspector.get_check_constraints(table)
            }

            assert f"ck_{table}_valid_dates" in constraints
            assert f"ck_{table}_start_precision" not in constraints
            assert f"ck_{table}_end_precision" not in constraints

    finally:
        engine.dispose()


@pytest.mark.parametrize(
    ("table", "destination_column", "destination_value"),
    [
        ("country_visits", "country_code", "AD"),
        ("city_visits", "city_id", 9_000_001),
    ],
)
def test_visit_precision_downgrade_converts_partial_end_dates(
    migration_config,
    table,
    destination_column,
    destination_value,
) -> None:
    """Downgrade converts partial end dates into valid exact-date ranges."""

    config, database_url = migration_config

    command.upgrade(config, "head")
    engine = create_engine(database_url)

    try:
        user_id = uuid4().hex
        visit_id = uuid4().hex

        with engine.begin() as connection:
            connection.execute(
                text(
                    """
                    INSERT INTO users (
                        id, username, display_name, password_hash
                    )
                    VALUES (
                        :id, :username, :display_name, :password_hash
                    )
                    """
                ),
                {
                    "id": user_id,
                    "username": "downgrade_test",
                    "display_name": "Downgrade Test",
                    "password_hash": "test_hash",
                },
            )

            if table == "city_visits":
                connection.execute(
                    text(
                        """
                        INSERT INTO cities (
                            id, country_code, name,
                            latitude, longitude, feature_code
                        )
                        VALUES (
                            :id, :country_code, :name,
                            :latitude, :longitude, :feature_code
                        )
                        """
                    ),
                    {
                        "id": destination_value,
                        "country_code": "AD",
                        "name": "Downgrade Test City",
                        "latitude": 42.5,
                        "longitude": 1.5,
                        "feature_code": "PPL",
                    },
                )

            # Table and column names are fixed by the test parametrization.
            connection.execute(
                text(
                    f"""
                    INSERT INTO {table} (
                        id,
                        user_id,
                        {destination_column},
                        started_on,
                        started_on_precision,
                        ended_on,
                        ended_on_precision
                    )
                    VALUES (
                        :id,
                        :user_id,
                        :destination,
                        :started_on,
                        :started_on_precision,
                        :ended_on,
                        :ended_on_precision
                    )
                    """
                ),
                {
                    "id": visit_id,
                    "user_id": user_id,
                    "destination": destination_value,
                    "started_on": "2024-08-20",
                    "started_on_precision": "day",
                    "ended_on": "2024-08-01",
                    "ended_on_precision": "month",
                },
            )

        command.downgrade(config, "644e0de73360")

        with engine.connect() as connection:
            visit = connection.execute(
                text(
                    f"""
                    SELECT started_on, ended_on
                    FROM {table}
                    WHERE id = :id
                    """
                ),
                {"id": visit_id},
            ).one()

            assert visit.started_on == "2024-08-20"
            assert visit.ended_on == "2024-08-31"

            violations = connection.execute(text("PRAGMA foreign_key_check")).all()

            assert violations == []

    finally:
        engine.dispose()
