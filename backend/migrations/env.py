from logging.config import fileConfig

from alembic import context

from app.core.config import get_settings
from app.db.base import Base
from app.db.session import create_database_engine
from app.models import (
    auth_session,  # noqa: F401
    country,  # noqa: F401
    country_visit,  # noqa: F401
    user,  # noqa: F401
)

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

config.set_main_option("sqlalchemy.url", get_settings().database_url)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    """Run migrations without a live database connection."""
    context.configure(
        url=get_settings().database_url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations using the application's database configuration."""
    connectable = create_database_engine(get_settings().database_url)

    try:
        with connectable.connect() as connection:
            is_sqlite = connection.dialect.name == "sqlite"

            if is_sqlite:
                # SQLite batch migrations may recreate referenced tables.
                # Disable FK enforcement before starting a transaction.
                connection.commit()
                connection.exec_driver_sql("PRAGMA foreign_keys = OFF")
                connection.commit()

                foreign_keys_enabled = connection.exec_driver_sql(
                    "PRAGMA foreign_keys"
                ).scalar_one()

                if foreign_keys_enabled != 0:
                    raise RuntimeError(
                        "Could not disable SQLite foreign key enforcement."
                    )

                connection.commit()

            try:
                context.configure(
                    connection=connection,
                    target_metadata=target_metadata,
                    compare_type=True,
                )

                with context.begin_transaction():
                    context.run_migrations()

                if is_sqlite:
                    violations = connection.exec_driver_sql(
                        "PRAGMA foreign_key_check"
                    ).fetchall()

                    if violations:
                        raise RuntimeError(
                            "Foreign key violations after migration: "
                            f"{violations}"
                        )
            finally:
                if is_sqlite:
                    connection.commit()
                    connection.exec_driver_sql("PRAGMA foreign_keys = ON")
                    connection.commit()

    finally:
        connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()