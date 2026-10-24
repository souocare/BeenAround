"""Import the prepared GeoNames city catalog into BeenAround."""

import argparse
import csv
import io
import json
import zipfile
from dataclasses import asdict, dataclass
from pathlib import Path
import math

from sqlalchemy import Engine, bindparam, select, update
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from app.core.config import get_settings
from app.db.session import create_database_engine
from app.models.city import City


CATALOG_MEMBER = "cities1000.csv"

CATALOG_FIELDS = (
    "id",
    "country_code",
    "name",
    "ascii_name",
    "latitude",
    "longitude",
    "population",
    "feature_code",
)

BATCH_SIZE = 1000


@dataclass(frozen=True)
class ImportReport:
    processed: int
    inserted: int
    updated: int


def parse_catalog_row(row: dict[str, str]) -> dict:
    if set(row) != set(CATALOG_FIELDS):
        raise ValueError("Invalid city catalog columns.")

    try:
        city_id = int(row["id"])
        latitude = float(row["latitude"])
        longitude = float(row["longitude"])
        population = int(row["population"]) if row["population"] else None
    except (ValueError, TypeError) as exc:
        raise ValueError("Invalid numeric city catalog field.") from exc

    if city_id <= 0:
        raise ValueError("Invalid city ID.")

    if not math.isfinite(latitude) or not -90 <= latitude <= 90:
        raise ValueError("Invalid latitude.")

    if not math.isfinite(longitude) or not -180 <= longitude <= 180:
        raise ValueError("Invalid longitude.")

    if population is not None and population < 0:
        raise ValueError("Invalid population.")

    if not row["country_code"] or len(row["country_code"]) != 2:
        raise ValueError("Invalid country code.")

    if not row["name"] or len(row["name"]) > 200:
        raise ValueError("Invalid city name.")

    if row["ascii_name"] and len(row["ascii_name"]) > 200:
        raise ValueError("Invalid ASCII city name.")

    if not row["feature_code"] or len(row["feature_code"]) > 10:
        raise ValueError("Invalid feature code.")

    return {
        "id": city_id,
        "country_code": row["country_code"],
        "name": row["name"],
        "ascii_name": row["ascii_name"] or None,
        "latitude": latitude,
        "longitude": longitude,
        "population": population,
        "feature_code": row["feature_code"],
    }


def import_cities(
    *,
    engine: Engine,
    catalog_path: Path,
) -> ImportReport:
    processed = 0
    inserted = 0
    updated = 0

    city_table = City.__table__

    with engine.begin() as connection:
        with zipfile.ZipFile(catalog_path) as archive:
            with archive.open(CATALOG_MEMBER) as raw_file:
                text_file = io.TextIOWrapper(
                    raw_file,
                    encoding="utf-8",
                    newline="",
                )
                reader = csv.DictReader(text_file)

                if reader.fieldnames != list(CATALOG_FIELDS):
                    raise ValueError("Unexpected city catalog schema.")

                batch = []

                for line_number, row in enumerate(reader, start=2):
                    try:
                        city = parse_catalog_row(row)
                    except ValueError as exc:
                        raise ValueError(f"Invalid city at CSV line {line_number}: {exc}") from exc

                    batch.append(city)

                    if len(batch) >= BATCH_SIZE:
                        batch_inserted, batch_updated = _upsert_batch(
                            connection,
                            city_table,
                            batch,
                        )
                        inserted += batch_inserted
                        updated += batch_updated
                        processed += len(batch)
                        batch.clear()

                if batch:
                    batch_inserted, batch_updated = _upsert_batch(
                        connection,
                        city_table,
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


def _upsert_batch(connection, city_table, batch: list[dict]) -> tuple[int, int]:
    ids = [city["id"] for city in batch]

    existing_ids = set(connection.scalars(select(city_table.c.id).where(city_table.c.id.in_(ids))))

    statement = sqlite_insert(city_table).values(batch)

    statement = statement.on_conflict_do_update(
        index_elements=[city_table.c.id],
        set_={
            "country_code": statement.excluded.country_code,
            "name": statement.excluded.name,
            "ascii_name": statement.excluded.ascii_name,
            "latitude": statement.excluded.latitude,
            "longitude": statement.excluded.longitude,
            "population": statement.excluded.population,
            "feature_code": statement.excluded.feature_code,
        },
    )

    connection.execute(statement)

    return len(batch) - len(existing_ids), len(existing_ids)


def main() -> None:
    parser = argparse.ArgumentParser(description="Import the prepared BeenAround city catalog.")

    parser.add_argument(
        "--catalog",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "app/data/cities1000.csv.zip",
    )

    args = parser.parse_args()

    engine = create_database_engine(get_settings().database_url)

    try:
        report = import_cities(
            engine=engine,
            catalog_path=args.catalog,
        )
    finally:
        engine.dispose()

    print(json.dumps(asdict(report), indent=2))


if __name__ == "__main__":
    main()
