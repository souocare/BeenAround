import csv
import io
import zipfile
from pathlib import Path

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.base import Base
from app.db.session import create_database_engine
from app.models.city import City
from app.models.country import Country
from scripts.geography.import_cities import import_cities


@pytest.fixture
def database_engine(tmp_path: Path):
    engine = create_database_engine(f"sqlite:///{tmp_path / 'cities.db'}")

    Base.metadata.create_all(engine)

    with Session(engine) as session:
        session.add(
            Country(
                code="PT",
                name="Portugal",
                alpha3_code="PRT",
                continent="Europe",
            )
        )
        session.commit()

    yield engine

    engine.dispose()


def write_catalog(path: Path, rows: list[dict]) -> None:
    buffer = io.StringIO(newline="")

    writer = csv.DictWriter(
        buffer,
        fieldnames=[
            "id",
            "country_code",
            "name",
            "ascii_name",
            "latitude",
            "longitude",
            "population",
            "feature_code",
        ],
        lineterminator="\n",
    )

    writer.writeheader()
    writer.writerows(rows)

    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr("cities1000.csv", buffer.getvalue())


def make_city_row(
    *,
    city_id: int = 2267057,
    name: str = "Lisbon",
    country_code: str = "PT",
) -> dict:
    return {
        "id": city_id,
        "country_code": country_code,
        "name": name,
        "ascii_name": name,
        "latitude": 38.7167,
        "longitude": -9.1333,
        "population": 500000,
        "feature_code": "PPL",
    }


def test_imports_cities(database_engine, tmp_path: Path) -> None:
    catalog = tmp_path / "cities.zip"

    write_catalog(
        catalog,
        [
            make_city_row(city_id=100, name="Lisbon"),
            make_city_row(city_id=200, name="Porto"),
        ],
    )

    report = import_cities(engine=database_engine, catalog_path=catalog)

    assert report.processed == 2
    assert report.inserted == 2
    assert report.updated == 0

    with Session(database_engine) as session:
        cities = session.scalars(select(City).order_by(City.id)).all()

        assert len(cities) == 2
        assert [city.name for city in cities] == ["Lisbon", "Porto"]


def test_import_is_idempotent(database_engine, tmp_path: Path) -> None:
    catalog = tmp_path / "cities.zip"
    write_catalog(catalog, [make_city_row()])

    first = import_cities(engine=database_engine, catalog_path=catalog)
    second = import_cities(engine=database_engine, catalog_path=catalog)

    assert first.inserted == 1
    assert second.inserted == 0
    assert second.updated == 1

    with Session(database_engine) as session:
        assert session.query(City).count() == 1


def test_updates_existing_city(database_engine, tmp_path: Path) -> None:
    catalog = tmp_path / "cities.zip"

    write_catalog(catalog, [make_city_row(name="Lisbon")])
    import_cities(engine=database_engine, catalog_path=catalog)

    write_catalog(catalog, [make_city_row(name="Lisboa")])
    report = import_cities(engine=database_engine, catalog_path=catalog)

    assert report.inserted == 0
    assert report.updated == 1

    with Session(database_engine) as session:
        city = session.get(City, 2267057)

        assert city is not None
        assert city.name == "Lisboa"


def test_missing_cities_are_not_deleted(database_engine, tmp_path: Path) -> None:
    catalog = tmp_path / "cities.zip"

    write_catalog(
        catalog,
        [
            make_city_row(city_id=100),
            make_city_row(city_id=200),
        ],
    )
    import_cities(engine=database_engine, catalog_path=catalog)

    write_catalog(catalog, [make_city_row(city_id=100)])
    import_cities(engine=database_engine, catalog_path=catalog)

    with Session(database_engine) as session:
        assert session.get(City, 100) is not None
        assert session.get(City, 200) is not None


def test_invalid_country_rolls_back_import(
    database_engine,
    tmp_path: Path,
) -> None:
    catalog = tmp_path / "cities.zip"

    write_catalog(
        catalog,
        [
            make_city_row(city_id=100),
            make_city_row(city_id=200, country_code="XX"),
        ],
    )

    with pytest.raises(Exception):
        import_cities(engine=database_engine, catalog_path=catalog)

    with Session(database_engine) as session:
        assert session.query(City).count() == 0


def test_invalid_coordinates_roll_back_import(
    database_engine,
    tmp_path: Path,
) -> None:
    catalog = tmp_path / "cities.zip"

    rows = [make_city_row(city_id=100)]

    invalid = make_city_row(city_id=200)
    invalid["latitude"] = 95

    rows.append(invalid)
    write_catalog(catalog, rows)

    with pytest.raises(ValueError):
        import_cities(engine=database_engine, catalog_path=catalog)

    with Session(database_engine) as session:
        assert session.query(City).count() == 0