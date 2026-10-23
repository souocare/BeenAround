import csv
import io
import json
import zipfile
from pathlib import Path

import pytest

from scripts.geography.prepare_cities import prepare_cities


def make_geonames_row(
    *,
    city_id: int,
    name: str,
    country_code: str = "PT",
    latitude: str = "38.7167",
    longitude: str = "-9.1333",
    population: str = "500000",
    feature_code: str = "PPL",
) -> list[str]:
    row = [""] * 19

    row[0] = str(city_id)
    row[1] = name
    row[2] = name
    row[4] = latitude
    row[5] = longitude
    row[6] = "P"
    row[7] = feature_code
    row[8] = country_code
    row[14] = population

    return row


def write_source(path: Path, rows: list[list[str]]) -> None:
    buffer = io.StringIO(newline="")
    writer = csv.writer(buffer, delimiter="\t", lineterminator="\n")
    writer.writerows(rows)

    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr("cities1000.txt", buffer.getvalue())


def write_countries(path: Path) -> None:
    path.write_text(
        json.dumps(
            [
                {"code": "PT"},
                {"code": "ES"},
            ]
        ),
        encoding="utf-8",
    )


def read_prepared(path: Path) -> list[dict[str, str]]:
    with zipfile.ZipFile(path) as archive:
        with archive.open("cities1000.csv") as raw_file:
            text_file = io.TextIOWrapper(raw_file, encoding="utf-8")
            return list(csv.DictReader(text_file))


def test_prepares_sorted_city_catalog(tmp_path: Path) -> None:
    source = tmp_path / "source.zip"
    countries = tmp_path / "countries.json"
    output = tmp_path / "cities.zip"

    write_countries(countries)
    write_source(
        source,
        [
            make_geonames_row(city_id=200, name="Porto"),
            make_geonames_row(city_id=100, name="Lisboa"),
        ],
    )

    report = prepare_cities(
        source=source,
        countries_path=countries,
        output=output,
    )

    cities = read_prepared(output)

    assert report.total == 2
    assert report.accepted == 2
    assert report.excluded == 0
    assert [city["id"] for city in cities] == ["100", "200"]
    assert cities[0]["name"] == "Lisboa"
    assert cities[0]["feature_code"] == "PPL"


def test_excludes_documented_unsupported_country(tmp_path: Path) -> None:
    source = tmp_path / "source.zip"
    countries = tmp_path / "countries.json"
    output = tmp_path / "cities.zip"

    write_countries(countries)
    write_source(
        source,
        [
            make_geonames_row(city_id=100, name="Lisboa"),
            make_geonames_row(
                city_id=200,
                name="Pristina",
                country_code="XK",
            ),
        ],
    )

    report = prepare_cities(
        source=source,
        countries_path=countries,
        output=output,
    )

    assert report.accepted == 1
    assert report.excluded == 1
    assert report.excluded_by_country == {"XK": 1}
    assert len(read_prepared(output)) == 1


def test_rejects_unexpected_country_code(tmp_path: Path) -> None:
    source = tmp_path / "source.zip"
    countries = tmp_path / "countries.json"
    output = tmp_path / "cities.zip"

    write_countries(countries)
    write_source(
        source,
        [
            make_geonames_row(
                city_id=100,
                name="Unknown",
                country_code="ZZ",
            )
        ],
    )

    with pytest.raises(ValueError, match="Unexpected GeoNames country code"):
        prepare_cities(
            source=source,
            countries_path=countries,
            output=output,
        )

    assert not output.exists()


def test_rejects_duplicate_geonames_ids(tmp_path: Path) -> None:
    source = tmp_path / "source.zip"
    countries = tmp_path / "countries.json"
    output = tmp_path / "cities.zip"

    write_countries(countries)
    write_source(
        source,
        [
            make_geonames_row(city_id=100, name="Lisboa"),
            make_geonames_row(city_id=100, name="Porto"),
        ],
    )

    with pytest.raises(ValueError, match="Duplicate GeoNames ID"):
        prepare_cities(
            source=source,
            countries_path=countries,
            output=output,
        )


@pytest.mark.parametrize(
    ("latitude", "longitude"),
    [
        ("91", "0"),
        ("-91", "0"),
        ("0", "181"),
        ("0", "-181"),
    ],
)
def test_rejects_invalid_coordinates(
    tmp_path: Path,
    latitude: str,
    longitude: str,
) -> None:
    source = tmp_path / "source.zip"
    countries = tmp_path / "countries.json"
    output = tmp_path / "cities.zip"

    write_countries(countries)
    write_source(
        source,
        [
            make_geonames_row(
                city_id=100,
                name="Invalid",
                latitude=latitude,
                longitude=longitude,
            )
        ],
    )

    with pytest.raises(ValueError, match="Invalid GeoNames record"):
        prepare_cities(
            source=source,
            countries_path=countries,
            output=output,
        )


def test_output_is_deterministic(tmp_path: Path) -> None:
    source = tmp_path / "source.zip"
    countries = tmp_path / "countries.json"
    output_a = tmp_path / "cities_a.zip"
    output_b = tmp_path / "cities_b.zip"

    write_countries(countries)
    write_source(
        source,
        [
            make_geonames_row(city_id=200, name="Porto"),
            make_geonames_row(city_id=100, name="Lisboa"),
        ],
    )

    prepare_cities(
        source=source,
        countries_path=countries,
        output=output_a,
    )

    prepare_cities(
        source=source,
        countries_path=countries,
        output=output_b,
    )

    assert output_a.read_bytes() == output_b.read_bytes()
