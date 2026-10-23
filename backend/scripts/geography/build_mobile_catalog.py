"""Build a standalone SQLite geography catalog for the mobile application."""

import argparse
import csv
import io
import json
import os
import sqlite3
import tempfile
import zipfile
from pathlib import Path

from scripts.geography.import_cities import (
    CATALOG_FIELDS,
    CATALOG_MEMBER,
    parse_catalog_row,
)

SCHEMA_VERSION = "1"
BATCH_SIZE = 1000

PROJECT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_COUNTRIES = PROJECT_ROOT / "app/data/countries.json"
DEFAULT_CITIES = PROJECT_ROOT / "app/data/cities1000.csv.zip"

COUNTRY_FIELDS = {"code", "alpha3_code", "name", "continent"}

CITY_COLUMNS = (
    "id",
    "country_code",
    "name",
    "ascii_name",
    "latitude",
    "longitude",
    "population",
    "feature_code",
)


def load_countries(path: Path) -> list[dict]:
    """Load and validate the country catalog."""

    countries = json.loads(path.read_text(encoding="utf-8"))

    if not isinstance(countries, list):
        raise ValueError("Country catalog must be a list.")

    seen_codes = set()
    seen_alpha3 = set()

    for country in countries:
        if not isinstance(country, dict):
            raise ValueError("Invalid country entry.")

        if set(country) != COUNTRY_FIELDS:
            raise ValueError("Invalid country catalog columns.")

        code = country["code"]
        alpha3 = country["alpha3_code"]

        if not isinstance(code, str) or len(code) != 2 or not code.isalpha() or not code.isupper():
            raise ValueError("Invalid country code.")

        if (
            not isinstance(alpha3, str)
            or len(alpha3) != 3
            or not alpha3.isalpha()
            or not alpha3.isupper()
        ):
            raise ValueError("Invalid alpha-3 country code.")

        if code in seen_codes or alpha3 in seen_alpha3:
            raise ValueError("Duplicate country code.")

        for field in ("name", "continent"):
            value = country[field]
            if not isinstance(value, str) or not value.strip():
                raise ValueError(f"Invalid country {field}.")

        if len(country["name"]) > 120:
            raise ValueError("Country name exceeds maximum length.")

        if len(country["continent"]) > 20:
            raise ValueError("Continent exceeds maximum length.")

        seen_codes.add(code)
        seen_alpha3.add(alpha3)

    return sorted(countries, key=lambda country: country["code"])


def create_schema(connection: sqlite3.Connection) -> None:
    """Create the standalone catalog schema."""

    connection.executescript(
        """
        CREATE TABLE countries (
            code TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            alpha3_code TEXT NOT NULL UNIQUE,
            continent TEXT NOT NULL
        );

        CREATE TABLE cities (
            id INTEGER PRIMARY KEY,
            country_code TEXT NOT NULL
                REFERENCES countries(code),
            name TEXT NOT NULL,
            ascii_name TEXT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            population INTEGER,
            feature_code TEXT NOT NULL
        );

        CREATE TABLE catalog_metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        """
    )


def insert_countries(
    connection: sqlite3.Connection,
    countries: list[dict],
) -> None:
    connection.executemany(
        """
        INSERT INTO countries (
            code,
            name,
            alpha3_code,
            continent
        )
        VALUES (?, ?, ?, ?)
        """,
        [
            (
                country["code"],
                country["name"],
                country["alpha3_code"],
                country["continent"],
            )
            for country in countries
        ],
    )


def insert_cities(
    connection: sqlite3.Connection,
    catalog_path: Path,
) -> int:
    """Stream validated GeoNames cities into the SQLite catalog."""

    total = 0
    batch = []

    placeholders = ", ".join("?" for _ in CITY_COLUMNS)
    columns = ", ".join(CITY_COLUMNS)

    statement = f"INSERT INTO cities ({columns}) VALUES ({placeholders})"

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

            for line_number, row in enumerate(reader, start=2):
                try:
                    city = parse_catalog_row(row)
                except ValueError as exc:
                    raise ValueError(f"Invalid city at CSV line {line_number}: {exc}") from exc

                batch.append(tuple(city[column] for column in CITY_COLUMNS))

                if len(batch) >= BATCH_SIZE:
                    connection.executemany(statement, batch)
                    total += len(batch)
                    batch.clear()

            if batch:
                connection.executemany(statement, batch)
                total += len(batch)

    return total


def create_indexes(connection: sqlite3.Connection) -> None:
    """Create indexes after bulk loading the city catalog."""

    connection.executescript(
        """
        CREATE INDEX idx_cities_country_name
        ON cities(country_code, name);

        CREATE INDEX idx_cities_country_population
        ON cities(country_code, population DESC);
        """
    )


def build_mobile_catalog(
    *,
    countries_path: Path,
    cities_path: Path,
    output_path: Path,
    version: str,
) -> dict[str, str | int]:
    """Generate and validate an independent SQLite geography catalog."""

    if not version.strip():
        raise ValueError("Catalog version cannot be empty.")

    countries = load_countries(countries_path)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    temporary_path = None

    try:
        with tempfile.NamedTemporaryFile(
            suffix=".sqlite",
            prefix=".beenaround-catalog-",
            dir=output_path.parent,
            delete=False,
        ) as temporary_file:
            temporary_path = Path(temporary_file.name)

        connection = sqlite3.connect(temporary_path)

        try:
            connection.execute("PRAGMA foreign_keys = ON")

            create_schema(connection)

            with connection:
                insert_countries(connection, countries)

                city_count = insert_cities(
                    connection,
                    cities_path,
                )

                create_indexes(connection)

                metadata = {
                    "schema_version": SCHEMA_VERSION,
                    "catalog_version": version,
                    "countries_count": str(len(countries)),
                    "cities_count": str(city_count),
                }

                connection.executemany(
                    """
                    INSERT INTO catalog_metadata (key, value)
                    VALUES (?, ?)
                    """,
                    sorted(metadata.items()),
                )

            foreign_key_errors = connection.execute("PRAGMA foreign_key_check").fetchall()

            if foreign_key_errors:
                raise ValueError("Catalog contains invalid country references.")

            integrity = connection.execute("PRAGMA integrity_check").fetchone()

            if integrity != ("ok",):
                raise ValueError("SQLite catalog integrity check failed.")

            actual_countries = connection.execute("SELECT COUNT(*) FROM countries").fetchone()[0]

            actual_cities = connection.execute("SELECT COUNT(*) FROM cities").fetchone()[0]

            if actual_countries != len(countries):
                raise ValueError("Country count mismatch.")

            if actual_cities != city_count:
                raise ValueError("City count mismatch.")

        finally:
            connection.close()

        os.chmod(temporary_path, 0o644)
        os.replace(temporary_path, output_path)
        temporary_path = None

        return {
            "catalog_version": version,
            "schema_version": SCHEMA_VERSION,
            "countries": len(countries),
            "cities": city_count,
            "output": str(output_path),
            "size_bytes": output_path.stat().st_size,
        }

    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Build the BeenAround mobile geography catalog.")

    parser.add_argument(
        "--countries",
        type=Path,
        default=DEFAULT_COUNTRIES,
    )

    parser.add_argument(
        "--cities",
        type=Path,
        default=DEFAULT_CITIES,
    )

    parser.add_argument(
        "--output",
        type=Path,
        required=True,
    )

    parser.add_argument(
        "--version",
        type=str,
        required=True,
    )

    args = parser.parse_args()

    report = build_mobile_catalog(
        countries_path=args.countries,
        cities_path=args.cities,
        output_path=args.output,
        version=args.version,
    )

    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
