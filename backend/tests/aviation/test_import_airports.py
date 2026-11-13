"""Tests for the OurAirports catalog importer."""

import csv

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.models.airport import Airport
from app.models.country import Country
from scripts.aviation.import_airports import (
    import_airports,
    parse_airport_row,
)


CSV_FIELDS = [
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
]


def airport_row(
    *,
    airport_id: str = "100",
    ident: str = "LPPT",
    name: str = "Lisbon Airport",
    country: str = "PT",
    latitude: str = "38.77",
    longitude: str = "-9.13",
    iata: str = "LIS",
    icao: str = "LPPT",
    scheduled_service: str = "yes",
) -> dict[str, str]:
    return {
        "id": airport_id,
        "ident": ident,
        "type": "large_airport",
        "name": name,
        "latitude_deg": latitude,
        "longitude_deg": longitude,
        "iso_country": country,
        "municipality": "Lisbon",
        "scheduled_service": scheduled_service,
        "icao_code": icao,
        "iata_code": iata,
    }


@pytest.fixture
def engine():
    database = create_engine(
        "sqlite+pysqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )

    Base.metadata.create_all(
        database,
        tables=[
            Country.__table__,
            Airport.__table__,
        ],
    )

    with database.begin() as connection:
        connection.execute(
            Country.__table__.insert(),
            {
                "code": "PT",
                "name": "Portugal",
                "alpha3_code": "PRT",
                "continent": "EU",
            },
        )

    yield database

    database.dispose()


def write_catalog(tmp_path, rows):
    path = tmp_path / "airports.csv"

    with path.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(
            file,
            fieldnames=CSV_FIELDS,
        )

        writer.writeheader()
        writer.writerows(rows)

    return path


def test_parses_valid_airport():
    airport = parse_airport_row(
        airport_row(),
        known_country_codes={"PT"},
    )

    assert airport["id"] == 100
    assert airport["ident"] == "LPPT"
    assert airport["iata_code"] == "LIS"
    assert airport["icao_code"] == "LPPT"
    assert airport["country_code"] == "PT"
    assert airport["source_country_code"] == "PT"
    assert airport["scheduled_service"] is True


def test_preserves_unknown_country_code():
    airport = parse_airport_row(
        airport_row(country="XK"),
        known_country_codes={"PT"},
    )

    assert airport["source_country_code"] == "XK"
    assert airport["country_code"] is None


def test_allows_missing_coordinates():
    airport = parse_airport_row(
        airport_row(
            latitude="",
            longitude="",
        ),
        known_country_codes={"PT"},
    )

    assert airport["latitude"] is None
    assert airport["longitude"] is None


@pytest.mark.parametrize(
    ("latitude", "longitude"),
    [
        ("91", "0"),
        ("0", "181"),
        ("NaN", "0"),
        ("inf", "0"),
        ("38", ""),
    ],
)
def test_rejects_invalid_coordinates(latitude, longitude):
    with pytest.raises(ValueError):
        parse_airport_row(
            airport_row(
                latitude=latitude,
                longitude=longitude,
            ),
            known_country_codes={"PT"},
        )


@pytest.mark.parametrize("value", ["", "maybe", "1", "true"])
def test_rejects_invalid_scheduled_service(value):
    with pytest.raises(ValueError):
        parse_airport_row(
            airport_row(scheduled_service=value),
            known_country_codes={"PT"},
        )


def test_imports_airports(engine, tmp_path):
    catalog = write_catalog(
        tmp_path,
        [
            airport_row(),
            airport_row(
                airport_id="101",
                ident="LPPR",
                name="Porto Airport",
                iata="OPO",
                icao="LPPR",
            ),
        ],
    )

    report = import_airports(
        engine=engine,
        catalog_path=catalog,
    )

    assert report.processed == 2
    assert report.inserted == 2
    assert report.updated == 0

    with engine.connect() as connection:
        airports = connection.execute(select(Airport.__table__).order_by(Airport.id)).all()

    assert len(airports) == 2
    assert airports[0].timezone_id == "Europe/Lisbon"
    assert airports[1].timezone_id == "Europe/Lisbon"


def test_reimport_updates_without_duplicates(engine, tmp_path):
    catalog = write_catalog(
        tmp_path,
        [airport_row()],
    )

    first = import_airports(
        engine=engine,
        catalog_path=catalog,
    )

    assert first.inserted == 1

    catalog = write_catalog(
        tmp_path,
        [airport_row(name="Updated Lisbon Airport")],
    )

    second = import_airports(
        engine=engine,
        catalog_path=catalog,
    )

    assert second.processed == 1
    assert second.inserted == 0
    assert second.updated == 1

    with engine.connect() as connection:
        airports = connection.execute(select(Airport.__table__)).all()

    assert len(airports) == 1
    assert airports[0].name == "Updated Lisbon Airport"


def test_import_is_atomic(engine, tmp_path):
    catalog = write_catalog(
        tmp_path,
        [
            airport_row(),
            airport_row(
                airport_id="101",
                ident="BAD",
                latitude="999",
            ),
        ],
    )

    with pytest.raises(ValueError):
        import_airports(
            engine=engine,
            catalog_path=catalog,
        )

    with engine.connect() as connection:
        airports = connection.execute(select(Airport.__table__)).all()

    assert airports == []


def test_reports_unknown_countries(engine, tmp_path):
    catalog = write_catalog(
        tmp_path,
        [
            airport_row(country="XK"),
        ],
    )

    report = import_airports(
        engine=engine,
        catalog_path=catalog,
    )

    assert report.unknown_country_codes == ["XK"]

    with engine.connect() as connection:
        airport = connection.execute(select(Airport.__table__)).one()

    assert airport.source_country_code == "XK"
    assert airport.country_code is None


def test_imports_airport_without_coordinates(engine, tmp_path):
    catalog = write_catalog(
        tmp_path,
        [
            airport_row(
                latitude="",
                longitude="",
            ),
        ],
    )

    report = import_airports(
        engine=engine,
        catalog_path=catalog,
    )

    assert report.inserted == 1

    with engine.connect() as connection:
        airport = connection.execute(select(Airport.__table__)).one()

    assert airport.timezone_id is None


def test_reimport_updates_airport_timezone(engine, tmp_path):
    catalog = write_catalog(
        tmp_path,
        [airport_row()],
    )

    import_airports(
        engine=engine,
        catalog_path=catalog,
    )

    with engine.connect() as connection:
        airport = connection.execute(select(Airport.__table__)).one()

    assert airport.timezone_id == "Europe/Lisbon"

    # Move the same catalog airport to coordinates
    # belonging to another timezone.
    catalog = write_catalog(
        tmp_path,
        [
            airport_row(
                latitude="35.5494",
                longitude="139.7798",
            ),
        ],
    )

    report = import_airports(
        engine=engine,
        catalog_path=catalog,
    )

    assert report.updated == 1

    with engine.connect() as connection:
        airport = connection.execute(select(Airport.__table__)).one()

    assert airport.timezone_id == "Asia/Tokyo"
