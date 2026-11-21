"""add airport trigram search index

Revision ID: a40699dd94cf
Revises: 704360cdf309
Create Date: 2026-11-21 10:01:53.414023

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a40699dd94cf'
down_revision: Union[str, Sequence[str], None] = '704360cdf309'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create and populate the airport trigram search index."""

    op.execute(
        """
        CREATE VIRTUAL TABLE airports_fts USING fts5(
            iata_code,
            icao_code,
            ident,
            name,
            municipality,
            content='airports',
            content_rowid='id',
            tokenize='trigram'
        )
        """
    )

    # Keep the index synchronized with airport inserts.
    op.execute(
        """
        CREATE TRIGGER airports_fts_ai
        AFTER INSERT ON airports
        BEGIN
            INSERT INTO airports_fts(
                rowid,
                iata_code,
                icao_code,
                ident,
                name,
                municipality
            )
            VALUES (
                new.id,
                new.iata_code,
                new.icao_code,
                new.ident,
                new.name,
                new.municipality
            );
        END
        """
    )

    # Remove deleted airports from the index.
    op.execute(
        """
        CREATE TRIGGER airports_fts_ad
        AFTER DELETE ON airports
        BEGIN
            INSERT INTO airports_fts(
                airports_fts,
                rowid,
                iata_code,
                icao_code,
                ident,
                name,
                municipality
            )
            VALUES (
                'delete',
                old.id,
                old.iata_code,
                old.icao_code,
                old.ident,
                old.name,
                old.municipality
            );
        END
        """
    )

    # Refresh indexed fields when an airport changes.
    op.execute(
        """
        CREATE TRIGGER airports_fts_au
        AFTER UPDATE OF
            iata_code,
            icao_code,
            ident,
            name,
            municipality
        ON airports
        BEGIN
            INSERT INTO airports_fts(
                airports_fts,
                rowid,
                iata_code,
                icao_code,
                ident,
                name,
                municipality
            )
            VALUES (
                'delete',
                old.id,
                old.iata_code,
                old.icao_code,
                old.ident,
                old.name,
                old.municipality
            );

            INSERT INTO airports_fts(
                rowid,
                iata_code,
                icao_code,
                ident,
                name,
                municipality
            )
            VALUES (
                new.id,
                new.iata_code,
                new.icao_code,
                new.ident,
                new.name,
                new.municipality
            );
        END
        """
    )

    # Existing airports predate the triggers.
    # Populate their index entries explicitly.
    op.execute(
        """
        INSERT INTO airports_fts(airports_fts)
        VALUES ('rebuild')
        """
    )


def downgrade() -> None:
    """Remove the airport search index and its triggers."""

    op.execute("DROP TRIGGER IF EXISTS airports_fts_au")
    op.execute("DROP TRIGGER IF EXISTS airports_fts_ad")
    op.execute("DROP TRIGGER IF EXISTS airports_fts_ai")

    op.execute("DROP TABLE IF EXISTS airports_fts")
