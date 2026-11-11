"""Import the OurAirports catalog into BeenAround.

The import is:
- Offline and based on a local CSV file.
- Transactional.
- Repeatable.
- Independent of Alembic migrations.
- Safe for existing airport references.
"""

import argparse
import csv
import json
import math
from dataclasses import asdict, dataclass
from pathlib import Path

from sqlalchemy import Engine, select
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from app.core.config import get_settings
from app.db.session import create_database_engine
from app.models.airport import Airport
from app.models.country import Country


BATCH_SIZE = 1000

REQUIRED_COLUMNS = frozenset(
    {
        "id",
        "ident",
        "type",
        "name",
        "latitude_deg",
        "longitude_deg",
        "iso_country",
        "municipality",
        "scheduled_service",
        "icao_code",
        "iata_code",
    }
)


@dataclass(frozen=True)
class ImportReport:
    processed: int
    inserted: int
    updated: int
    unknown_country_codes: list[str]


def _optional_text(
    value: str | None,
    *,
    max_length: int,
) -> str | None:
    if value is None:
        return None

    normalized = value.strip()

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


def _coordinate(
    value: str | None,
    *,
    minimum: float,
    maximum: float,
) -> float | None:
    if value is None or not value.strip():
        return None

    try:
        coordinate = float(value)
    except (ValueError, TypeError) as exc:
        raise ValueError("Invalid coordinate.") from exc

    if not math.isfinite(coordinate):
        raise ValueError("Coordinate must be finite.")

    if not minimum <= coordinate <= maximum:
        raise ValueError("Coordinate is out of range.")

    return coordinate


def parse_airport_row(
    row: dict[str, str | None],
    *,
    known_country_codes: set[str],
) -> dict:
    """Validate and normalize one OurAirports CSV record."""

    try:
        airport_id = int(row["id"] or "")
    except (ValueError, TypeError) as exc:
        raise ValueError("Invalid airport ID.") from exc

    if airport_id <= 0:
        raise ValueError("Airport ID must be positive.")

    ident = _required_text(
        row.get("ident"),
        max_length=20,
    )

    name = _required_text(
        row.get("name"),
        max_length=200,
    )

    airport_type = _required_text(
        row.get("type"),
        max_length=30,
    )

    municipality = _optional_text(
        row.get("municipality"),
        max_length=200,
    )

    iata_code = _optional_text(
        row.get("iata_code"),
        max_length=3,
    )

    icao_code = _optional_text(
        row.get("icao_code"),
        max_length=4,
    )

    if iata_code is not None:
        iata_code = iata_code.upper()

    if icao_code is not None:
        icao_code = icao_code.upper()

    source_country_code = _optional_text(
        row.get("iso_country"),
        max_length=2,
    )

    if source_country_code is not None:
        source_country_code = source_country_code.upper()

        if len(source_country_code) != 2:
            raise ValueError("Invalid country code.")

    country_code = source_country_code if source_country_code in known_country_codes else None

    latitude = _coordinate(
        row.get("latitude_deg"),
        minimum=-90,
        maximum=90,
    )

    longitude = _coordinate(
        row.get("longitude_deg"),
        minimum=-180,
        maximum=180,
    )

    # Coordinates must be complete or entirely absent.
    if (latitude is None) != (longitude is None):
        raise ValueError("Airport coordinates must be complete.")

    scheduled_service = (row.get("scheduled_service") or "").strip().lower()

    if scheduled_service not in {"yes", "no"}:
        raise ValueError("scheduled_service must be 'yes' or 'no'.")

    return {
        "id": airport_id,
        "ident": ident,
        "iata_code": iata_code,
        "icao_code": icao_code,
        "name": name,
        "municipality": municipality,
        "source_country_code": source_country_code,
        "country_code": country_code,
        "latitude": latitude,
        "longitude": longitude,
        "type": airport_type,
        "scheduled_service": scheduled_service == "yes",
    }


def _upsert_batch(
    connection,
    batch: list[dict],
) -> tuple[int, int]:
    """Insert or update airports, preserving stable IDs."""

    airport_table = Airport.__table__

    ids = [airport["id"] for airport in batch]

    existing_ids = set(
        connection.scalars(select(airport_table.c.id).where(airport_table.c.id.in_(ids)))
    )

    statement = sqlite_insert(airport_table).values(batch)

    update_columns = {
        column.name: getattr(statement.excluded, column.name)
        for column in airport_table.columns
        if column.name != "id"
    }

    statement = statement.on_conflict_do_update(
        index_elements=[airport_table.c.id],
        set_=update_columns,
    )

    connection.execute(statement)

    return (
        len(batch) - len(existing_ids),
        len(existing_ids),
    )


def import_airports(
    *,
    engine: Engine,
    catalog_path: Path,
) -> ImportReport:
    """Import a local OurAirports CSV in one transaction."""

    processed = 0
    inserted = 0
    updated = 0

    unknown_country_codes: set[str] = set()

    with engine.begin() as connection:
        known_country_codes = set(connection.scalars(select(Country.code)))

        with catalog_path.open(
            "r",
            encoding="utf-8-sig",
            newline="",
        ) as csv_file:
            reader = csv.DictReader(csv_file)

            if reader.fieldnames is None:
                raise ValueError("Airport catalog is empty.")

            if len(reader.fieldnames) != len(
                set(reader.fieldnames)
            ) or not REQUIRED_COLUMNS.issubset(reader.fieldnames):
                raise ValueError("Unexpected OurAirports catalog schema.")

            batch: list[dict] = []

            for line_number, row in enumerate(reader, start=2):
                if None in row:
                    raise ValueError(f"Invalid CSV structure at line {line_number}.")

                try:
                    airport = parse_airport_row(
                        row,
                        known_country_codes=known_country_codes,
                    )
                except ValueError as exc:
                    raise ValueError(f"Invalid airport at CSV line {line_number}: {exc}") from exc

                source_code = airport["source_country_code"]

                if source_code is not None and airport["country_code"] is None:
                    unknown_country_codes.add(source_code)

                batch.append(airport)

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
        unknown_country_codes=sorted(unknown_country_codes),
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Import the OurAirports airport catalog.")

    parser.add_argument(
        "--catalog",
        required=True,
        type=Path,
        help="Path to the locally downloaded airports.csv file.",
    )

    args = parser.parse_args()

    engine = create_database_engine(get_settings().database_url)

    try:
        report = import_airports(
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
