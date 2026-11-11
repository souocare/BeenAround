"""Import the AviationShop airline catalog into BeenAround.

The importer:
- Reads a local CSV without network access.
- Validates records before persistence.
- Uses stable-within-source normalized name keys.
- Preserves internal airline IDs and existing callsigns.
- Performs all writes in one transaction.
- Never deletes historical airlines.
"""

import argparse
import csv
import json
from dataclasses import asdict, dataclass
from pathlib import Path

from sqlalchemy import Engine, select
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from app.core.config import get_settings
from app.db.session import create_database_engine
from app.models.airline import Airline


BATCH_SIZE = 100

CATALOG_FIELDS = (
    "iata",
    "icao",
    "airline",
    "country",
)

SOURCE_NAMESPACE = "aviationshop:name:"


@dataclass(frozen=True)
class ImportReport:
    processed: int
    inserted: int
    updated: int


def _optional_text(
    value: str | None,
    *,
    max_length: int,
) -> str | None:
    if value is None:
        return None

    normalized = " ".join(value.split())

    if not normalized:
        return None

    if len(normalized) > max_length:
        raise ValueError(f"Text exceeds maximum length of {max_length}.")

    return normalized


def _required_text(
    value: str | None,
    *,
    max_length: int,
) -> str:
    normalized = _optional_text(
        value,
        max_length=max_length,
    )

    if normalized is None:
        raise ValueError("Required text field is empty.")

    return normalized


def _optional_code(
    value: str | None,
    *,
    expected_length: int,
) -> str | None:
    normalized = _optional_text(
        value,
        max_length=expected_length,
    )

    if normalized is None:
        return None

    normalized = normalized.upper()

    if len(normalized) != expected_length:
        raise ValueError(f"Code must contain exactly {expected_length} characters.")

    if not normalized.isascii() or not normalized.isalnum():
        raise ValueError("Code must contain ASCII letters or digits.")

    return normalized


def build_source_key(name: str) -> str:
    """Build a deterministic source key from an airline name.

    This key is stable across changes to case and whitespace,
    but not across airline renames.
    """

    normalized_name = " ".join(name.split()).casefold()

    if not normalized_name:
        raise ValueError("Cannot build a key from an empty airline name.")

    source_key = f"{SOURCE_NAMESPACE}{normalized_name}"

    if len(source_key) > 150:
        raise ValueError("Airline source key exceeds 150 characters.")

    return source_key


def parse_airline_row(
    row: dict[str, str | None],
) -> dict:
    """Validate and normalize one AviationShop CSV record."""

    name = _required_text(
        row.get("airline"),
        max_length=200,
    )

    iata_code = _optional_code(
        row.get("iata"),
        expected_length=2,
    )

    icao_code = _optional_code(
        row.get("icao"),
        expected_length=3,
    )

    country_name = _optional_text(
        row.get("country"),
        max_length=120,
    )

    return {
        "name": name,
        "iata_code": iata_code,
        "icao_code": icao_code,
        "callsign": None,
        "country_name": country_name,
        "source_key": build_source_key(name),
    }


def _upsert_batch(
    connection,
    batch: list[dict],
) -> tuple[int, int]:
    """Insert or update airlines without changing their internal IDs."""

    airline_table = Airline.__table__

    source_keys = [airline["source_key"] for airline in batch]

    existing_keys = set(
        connection.scalars(
            select(airline_table.c.source_key).where(airline_table.c.source_key.in_(source_keys))
        )
    )

    statement = sqlite_insert(airline_table)

    statement = statement.on_conflict_do_update(
        index_elements=[airline_table.c.source_key],
        set_={
            "name": statement.excluded.name,
            "iata_code": statement.excluded.iata_code,
            "icao_code": statement.excluded.icao_code,
            "country_name": statement.excluded.country_name,
        },
    )

    # Executemany avoids creating an excessively large statement
    # and its associated SQLite parameter limits.
    connection.execute(statement, batch)

    return (
        len(batch) - len(existing_keys),
        len(existing_keys),
    )


def import_airlines(
    *,
    engine: Engine,
    catalog_path: Path,
) -> ImportReport:
    """Import a local airline CSV using one atomic transaction."""

    processed = 0
    inserted = 0
    updated = 0

    seen_source_keys: set[str] = set()

    with engine.begin() as connection:
        with catalog_path.open(
            "r",
            encoding="utf-8-sig",
            newline="",
        ) as csv_file:
            reader = csv.DictReader(csv_file)

            if reader.fieldnames != list(CATALOG_FIELDS):
                raise ValueError("Unexpected AviationShop airline catalog schema.")

            batch: list[dict] = []

            for line_number, row in enumerate(reader, start=2):
                if None in row:
                    raise ValueError(f"Invalid CSV structure at line {line_number}.")

                try:
                    airline = parse_airline_row(row)

                    source_key = airline["source_key"]

                    if source_key in seen_source_keys:
                        raise ValueError(f"Duplicate airline source key: {source_key}")

                    seen_source_keys.add(source_key)

                except ValueError as exc:
                    raise ValueError(f"Invalid airline at CSV line {line_number}: {exc}") from exc

                batch.append(airline)

                if len(batch) >= BATCH_SIZE:
                    batch_inserted, batch_updated = _upsert_batch(
                        connection,
                        batch,
                    )

                    inserted += batch_inserted
                    updated += batch_updated
                    processed += len(batch)

                    batch.clear()

            if batch:
                batch_inserted, batch_updated = _upsert_batch(
                    connection,
                    batch,
                )

                inserted += batch_inserted
                updated += batch_updated
                processed += len(batch)

    return ImportReport(
        processed=processed,
        inserted=inserted,
        updated=updated,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Import the AviationShop airline catalog.")

    parser.add_argument(
        "--catalog",
        required=True,
        type=Path,
        help="Path to a local AviationShop airline CSV.",
    )

    args = parser.parse_args()

    engine = create_database_engine(get_settings().database_url)

    try:
        report = import_airlines(
            engine=engine,
            catalog_path=args.catalog,
        )
    finally:
        engine.dispose()

    print(
        json.dumps(
            asdict(report),
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
