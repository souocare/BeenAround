"""Integration tests for the airport FTS5 trigram migration."""

import importlib

from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import create_engine, text

from app.db.base import Base
from app.models.airport import Airport
from app.models.country import Country


migration = importlib.import_module(
    "migrations.versions.a40699dd94cf_add_airport_trigram_search_index"
)


def test_airport_fts_migration_lifecycle():
    """FTS5 remains synchronized with airport catalog changes."""

    engine = create_engine("sqlite+pysqlite:///:memory:")

    try:
        with engine.begin() as connection:
            Base.metadata.create_all(
                connection,
                tables=[
                    Country.__table__,
                    Airport.__table__,
                ],
            )

            connection.execute(
                Country.__table__.insert(),
                {
                    "code": "PT",
                    "name": "Portugal",
                    "alpha3_code": "PRT",
                    "continent": "Europe",
                },
            )

            # An existing airport must be indexed by the rebuild.
            connection.execute(
                Airport.__table__.insert(),
                {
                    "id": 100,
                    "ident": "LPPT",
                    "name": "Lisbon Airport",
                    "iata_code": "LIS",
                    "icao_code": "LPPT",
                    "country_code": "PT",
                    "type": "large_airport",
                    "scheduled_service": True,
                },
            )

            context = MigrationContext.configure(connection)

            with Operations.context(context):
                migration.upgrade()

            def search(term: str) -> list[int]:
                rows = connection.execute(
                    text(
                        """
                        SELECT rowid
                        FROM airports_fts
                        WHERE airports_fts MATCH :term
                        ORDER BY rowid
                        """
                    ),
                    {"term": term},
                ).all()

                return [row[0] for row in rows]

            # Existing records are available after rebuild.
            assert search("lis") == [100]

            # INSERT trigger.
            connection.execute(
                Airport.__table__.insert(),
                {
                    "id": 101,
                    "ident": "LPPR",
                    "name": "Porto Airport",
                    "iata_code": "OPO",
                    "icao_code": "LPPR",
                    "country_code": "PT",
                    "type": "large_airport",
                    "scheduled_service": True,
                },
            )

            assert search("porto") == [101]

            # UPDATE trigger.
            connection.execute(
                text(
                    """
                    UPDATE airports
                    SET name = 'Coimbra Airport',
                        ident = 'PTCO',
                        iata_code = NULL,
                        icao_code = NULL
                    WHERE id = 101
                    """
                )
            )

            assert search("coi") == [101]
            assert search("porto") == []

            # DELETE trigger.
            connection.execute(text("DELETE FROM airports WHERE id = 101"))

            assert search("coi") == []

            # Downgrade must preserve the catalog.
            with Operations.context(context):
                migration.downgrade()

            remaining = connection.scalar(text("SELECT COUNT(*) FROM airports"))

            assert remaining == 1

            fts_table = connection.scalar(
                text(
                    """
                    SELECT COUNT(*)
                    FROM sqlite_master
                    WHERE type = 'table'
                      AND name = 'airports_fts'
                    """
                )
            )

            assert fts_table == 0

    finally:
        engine.dispose()
