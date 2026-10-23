"""Tests for the standalone mobile geography catalog builder."""

import csv
import json
import sqlite3
import zipfile
from pathlib import Path

import pytest

from scripts.geography.build_mobile_catalog import (
    build_mobile_catalog,
    load_countries,
)


@pytest.fixture
def catalog_sources(tmp_path: Path) -> tuple[Path, Path]:
    countries_path = tmp_path / "countries.json"
    cities_path = tmp_path / "cities.zip"

    countries = [
        {
            "code": "PT",
            "alpha3_code": "PRT",
            "name": "Portugal",
            "continent": "Europe",
        },
        {
            "code": "FR",
            "alpha3_code": "FRA",
            "name": "France",
            "continent": "Europe",
        },
    ]

    countries_path.write_text(
        json.dumps(countries),
        encoding="utf-8",
    )

    csv_path = tmp_path / "cities1000.csv"

    with csv_path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.writer(file)

        writer.writerow(
            [
                "id",
                "country_code",
                "name",
                "ascii_name",
                "latitude",
                "longitude",
                "population",
                "feature_code",
            ]
        )

        writer.writerow([2267057, "PT", "Lisbon", "Lisbon", 38.71667, -9.13333, 517802, "PPLC"])

        writer.writerow([2735943, "PT", "Porto", "Porto", 41.14961, -8.61099, 249633, "PPLA"])

        writer.writerow([2988507, "FR", "Paris", "Paris", 48.85341, 2.3488, 2138551, "PPLC"])

    with zipfile.ZipFile(cities_path, "w") as archive:
        archive.write(csv_path, arcname="cities1000.csv")

    return countries_path, cities_path


def test_build_mobile_catalog_creates_expected_data(
    catalog_sources: tuple[Path, Path],
    tmp_path: Path,
) -> None:
    countries_path, cities_path = catalog_sources
    output_path = tmp_path / "catalog.sqlite"

    report = build_mobile_catalog(
        countries_path=countries_path,
        cities_path=cities_path,
        output_path=output_path,
        version="test-1",
    )

    assert report["countries"] == 2
    assert report["cities"] == 3
    assert report["schema_version"] == "1"
    assert output_path.is_file()

    with sqlite3.connect(output_path) as connection:
        countries = connection.execute("SELECT code FROM countries ORDER BY code").fetchall()

        cities = connection.execute(
            "SELECT id, name, country_code FROM cities ORDER BY id"
        ).fetchall()

        metadata = dict(connection.execute("SELECT key, value FROM catalog_metadata").fetchall())

        assert countries == [("FR",), ("PT",)]

        assert cities == [
            (2267057, "Lisbon", "PT"),
            (2735943, "Porto", "PT"),
            (2988507, "Paris", "FR"),
        ]

        assert metadata == {
            "schema_version": "1",
            "catalog_version": "test-1",
            "countries_count": "2",
            "cities_count": "3",
        }


def test_build_mobile_catalog_rejects_unknown_country(
    catalog_sources: tuple[Path, Path],
    tmp_path: Path,
) -> None:
    countries_path, cities_path = catalog_sources

    countries = json.loads(countries_path.read_text(encoding="utf-8"))
    countries = [country for country in countries if country["code"] != "FR"]

    countries_path.write_text(
        json.dumps(countries),
        encoding="utf-8",
    )

    output_path = tmp_path / "catalog.sqlite"

    with pytest.raises(sqlite3.IntegrityError):
        build_mobile_catalog(
            countries_path=countries_path,
            cities_path=cities_path,
            output_path=output_path,
            version="test-1",
        )

    assert not output_path.exists()


def test_build_mobile_catalog_rejects_invalid_version(
    catalog_sources: tuple[Path, Path],
    tmp_path: Path,
) -> None:
    countries_path, cities_path = catalog_sources

    with pytest.raises(ValueError, match="version"):
        build_mobile_catalog(
            countries_path=countries_path,
            cities_path=cities_path,
            output_path=tmp_path / "catalog.sqlite",
            version=" ",
        )


def test_load_countries_rejects_duplicates(tmp_path: Path) -> None:
    path = tmp_path / "countries.json"

    path.write_text(
        json.dumps(
            [
                {
                    "code": "PT",
                    "alpha3_code": "PRT",
                    "name": "Portugal",
                    "continent": "Europe",
                },
                {
                    "code": "PT",
                    "alpha3_code": "PRT",
                    "name": "Portugal",
                    "continent": "Europe",
                },
            ]
        ),
        encoding="utf-8",
    )

    with pytest.raises(ValueError, match="Duplicate"):
        load_countries(path)


def test_catalog_build_is_deterministic(
    catalog_sources: tuple[Path, Path],
    tmp_path: Path,
) -> None:
    countries_path, cities_path = catalog_sources

    first = tmp_path / "first.sqlite"
    second = tmp_path / "second.sqlite"

    for output in (first, second):
        build_mobile_catalog(
            countries_path=countries_path,
            cities_path=cities_path,
            output_path=output,
            version="test-1",
        )

    assert first.read_bytes() == second.read_bytes()


def test_failed_build_preserves_existing_catalog(
    catalog_sources: tuple[Path, Path],
    tmp_path: Path,
) -> None:
    countries_path, cities_path = catalog_sources
    output_path = tmp_path / "catalog.sqlite"

    output_path.write_bytes(b"existing catalog")

    with pytest.raises(ValueError, match="version"):
        build_mobile_catalog(
            countries_path=countries_path,
            cities_path=cities_path,
            output_path=output_path,
            version="",
        )

    assert output_path.read_bytes() == b"existing catalog"
