"""Tests for the AviationShop airline catalog importer."""

import csv

import pytest
from sqlalchemy import create_engine, select
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.models.airline import Airline
from scripts.aviation.import_airlines import (
    build_source_key,
    import_airlines,
    parse_airline_row,
)


CSV_FIELDS = [
    "iata",
    "icao",
    "airline",
    "country",
]


def airline_row(
    *,
    iata: str = "TP",
    icao: str = "TAP",
    name: str = "TAP Air Portugal",
    country: str = "Portugal",
) -> dict[str, str]:
    return {
        "iata": iata,
        "icao": icao,
        "airline": name,
        "country": country,
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
        tables=[Airline.__table__],
    )

    yield database

    database.dispose()


def write_catalog(tmp_path, rows):
    path = tmp_path / "airline-codes.csv"

    with path.open(
        "w",
        encoding="utf-8",
        newline="",
    ) as file:
        writer = csv.DictWriter(
            file,
            fieldnames=CSV_FIELDS,
        )

        writer.writeheader()
        writer.writerows(rows)

    return path


def test_parses_valid_airline():
    airline = parse_airline_row(airline_row())

    assert airline["name"] == "TAP Air Portugal"
    assert airline["iata_code"] == "TP"
    assert airline["icao_code"] == "TAP"
    assert airline["country_name"] == "Portugal"
    assert airline["callsign"] is None
    assert airline["source_key"] == ("aviationshop:name:tap air portugal")


def test_normalizes_codes_and_whitespace():
    airline = parse_airline_row(
        airline_row(
            iata="tp",
            icao="tap",
            name="  TAP   Air   Portugal  ",
        )
    )

    assert airline["iata_code"] == "TP"
    assert airline["icao_code"] == "TAP"
    assert airline["name"] == "TAP Air Portugal"


def test_source_key_is_case_insensitive():
    first = build_source_key("TAP Air Portugal")
    second = build_source_key(" tap   AIR portugal ")

    assert first == second


def test_optional_codes_are_supported():
    airline = parse_airline_row(
        airline_row(
            iata="",
            icao="",
        )
    )

    assert airline["iata_code"] is None
    assert airline["icao_code"] is None


@pytest.mark.parametrize(
    ("iata", "icao"),
    [
        ("T", "TAP"),
        ("TPP", "TAP"),
        ("TP", "TA"),
        ("TP", "TAPP"),
        ("T!", "TAP"),
        ("TP", "TA!"),
    ],
)
def test_rejects_invalid_codes(iata, icao):
    with pytest.raises(ValueError):
        parse_airline_row(
            airline_row(
                iata=iata,
                icao=icao,
            )
        )


def test_rejects_empty_name():
    with pytest.raises(ValueError):
        parse_airline_row(airline_row(name="   "))


def test_preserves_country_as_text():
    airline = parse_airline_row(airline_row(country="Unknown Historical Territory"))

    assert airline["country_name"] == ("Unknown Historical Territory")


def test_imports_airlines(engine, tmp_path):
    catalog = write_catalog(
        tmp_path,
        [
            airline_row(),
            airline_row(
                iata="FR",
                icao="RYR",
                name="Ryanair",
                country="Ireland",
            ),
        ],
    )

    report = import_airlines(
        engine=engine,
        catalog_path=catalog,
    )

    assert report.processed == 2
    assert report.inserted == 2
    assert report.updated == 0

    with engine.connect() as connection:
        airlines = connection.execute(select(Airline.__table__).order_by(Airline.id)).all()

    assert len(airlines) == 2
    assert airlines[0].name == "TAP Air Portugal"
    assert airlines[1].name == "Ryanair"


def test_reimport_preserves_id(engine, tmp_path):
    catalog = write_catalog(
        tmp_path,
        [airline_row()],
    )

    first = import_airlines(
        engine=engine,
        catalog_path=catalog,
    )

    assert first.inserted == 1

    with engine.connect() as connection:
        original_id = connection.scalar(select(Airline.id))

    updated_catalog = write_catalog(
        tmp_path,
        [
            airline_row(
                iata="ZZ",
                icao="ZZZ",
            )
        ],
    )

    second = import_airlines(
        engine=engine,
        catalog_path=updated_catalog,
    )

    assert second.processed == 1
    assert second.inserted == 0
    assert second.updated == 1

    with engine.connect() as connection:
        airline = connection.execute(select(Airline.__table__)).one()

    assert airline.id == original_id
    assert airline.iata_code == "ZZ"
    assert airline.icao_code == "ZZZ"


def test_reimport_preserves_callsign(engine, tmp_path):
    catalog = write_catalog(
        tmp_path,
        [airline_row()],
    )

    import_airlines(
        engine=engine,
        catalog_path=catalog,
    )

    with engine.begin() as connection:
        connection.execute(Airline.__table__.update().values(callsign="AIR PORTUGAL"))

    import_airlines(
        engine=engine,
        catalog_path=catalog,
    )

    with engine.connect() as connection:
        airline = connection.execute(select(Airline.__table__)).one()

    assert airline.callsign == "AIR PORTUGAL"


def test_rejects_duplicate_source_keys(engine, tmp_path):
    catalog = write_catalog(
        tmp_path,
        [
            airline_row(name="TAP Air Portugal"),
            airline_row(name=" tap   AIR portugal "),
        ],
    )

    with pytest.raises(
        ValueError,
        match="Duplicate airline source key",
    ):
        import_airlines(
            engine=engine,
            catalog_path=catalog,
        )

    with engine.connect() as connection:
        airlines = connection.execute(select(Airline.__table__)).all()

    assert airlines == []


def test_import_is_atomic(engine, tmp_path):
    catalog = write_catalog(
        tmp_path,
        [
            airline_row(),
            airline_row(
                name="Invalid Airline",
                iata="INVALID",
            ),
        ],
    )

    with pytest.raises(ValueError):
        import_airlines(
            engine=engine,
            catalog_path=catalog,
        )

    with engine.connect() as connection:
        airlines = connection.execute(select(Airline.__table__)).all()

    assert airlines == []


def test_airline_rename_creates_new_record(engine, tmp_path):
    original_catalog = write_catalog(
        tmp_path,
        [airline_row(name="Original Airline")],
    )

    import_airlines(
        engine=engine,
        catalog_path=original_catalog,
    )

    updated_catalog = write_catalog(
        tmp_path,
        [airline_row(name="Renamed Airline")],
    )

    import_airlines(
        engine=engine,
        catalog_path=updated_catalog,
    )

    with engine.connect() as connection:
        airlines = connection.execute(select(Airline.__table__)).all()

    assert len(airlines) == 2
