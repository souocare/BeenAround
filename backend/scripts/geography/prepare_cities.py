"""Prepare the BeenAround city catalog from GeoNames cities1000."""

import argparse
import csv
import io
import json
import zipfile
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
import math
import os
import tempfile


FIELD_NAMES = (
    "id",
    "country_code",
    "name",
    "ascii_name",
    "latitude",
    "longitude",
    "population",
    "feature_code",
)

GEONAMES_FIELD_COUNT = 19
GEONAMES_MEMBER = "cities1000.txt"

# GeoNames uses XK for Kosovo, which is not in our ISO 3166-1 catalog.
ALLOWED_EXCLUDED_COUNTRY_CODES = frozenset({"XK"})


@dataclass(frozen=True)
class CityRecord:
    id: int
    country_code: str
    name: str
    ascii_name: str | None
    latitude: float
    longitude: float
    population: int | None
    feature_code: str


@dataclass(frozen=True)
class PreparationReport:
    total: int
    accepted: int
    excluded: int
    excluded_by_reason: dict[str, int]
    excluded_by_country: dict[str, int]


def load_country_codes(path: Path) -> set[str]:
    countries = json.loads(path.read_text(encoding="utf-8"))

    if not isinstance(countries, list):
        raise ValueError("Country catalog must contain a JSON list.")

    codes = set()

    for country in countries:
        code = country["code"]

        if not isinstance(code, str) or len(code) != 2:
            raise ValueError(f"Invalid country code: {code!r}")

        if code in codes:
            raise ValueError(f"Duplicate country code: {code}")

        codes.add(code)

    return codes


def parse_city(row: list[str]) -> CityRecord:
    if len(row) != GEONAMES_FIELD_COUNT:
        raise ValueError(f"Expected 19 GeoNames fields, got {len(row)}.")

    city_id = int(row[0])
    name = row[1]
    ascii_name = row[2] or None
    latitude = float(row[4])
    longitude = float(row[5])
    feature_class = row[6]
    feature_code = row[7]
    country_code = row[8]
    population = int(row[14]) if row[14] else None

    if city_id <= 0:
        raise ValueError("GeoNames ID must be positive.")

    if not name or len(name) > 200:
        raise ValueError("Invalid city name.")

    if ascii_name is not None and len(ascii_name) > 200:
        raise ValueError("Invalid ASCII city name.")

    if not math.isfinite(latitude) or not -90 <= latitude <= 90:
        raise ValueError("Invalid latitude.")

    if not math.isfinite(longitude) or not -180 <= longitude <= 180:
        raise ValueError("Invalid longitude.")

    if population is not None and population < 0:
        raise ValueError("Invalid population.")

    if feature_class != "P":
        raise ValueError("Expected populated-place feature class.")

    if not feature_code or len(feature_code) > 10:
        raise ValueError("Invalid feature code.")

    if len(country_code) != 2:
        raise ValueError("Invalid country code.")

    return CityRecord(
        id=city_id,
        country_code=country_code,
        name=name,
        ascii_name=ascii_name,
        latitude=latitude,
        longitude=longitude,
        population=population,
        feature_code=feature_code,
    )


def prepare_cities(
    *,
    source: Path,
    countries_path: Path,
    output: Path,
) -> PreparationReport:
    country_codes = load_country_codes(countries_path)

    accepted: list[CityRecord] = []
    seen_ids: set[int] = set()

    excluded_by_reason: Counter[str] = Counter()
    excluded_by_country: Counter[str] = Counter()

    total = 0

    with zipfile.ZipFile(source) as archive:
        with archive.open(GEONAMES_MEMBER) as raw_file:
            text_file = io.TextIOWrapper(raw_file, encoding="utf-8", newline="")
            reader = csv.reader(text_file, delimiter="\t")

            for line_number, row in enumerate(reader, start=1):
                total += 1

                try:
                    city = parse_city(row)
                except (ValueError, TypeError) as exc:
                    raise ValueError(
                        f"Invalid GeoNames record at line {line_number}: {exc}"
                    ) from exc

                if city.id in seen_ids:
                    raise ValueError(f"Duplicate GeoNames ID {city.id} at line {line_number}.")

                seen_ids.add(city.id)

                if city.country_code not in country_codes:
                    if city.country_code not in ALLOWED_EXCLUDED_COUNTRY_CODES:
                        raise ValueError(
                            "Unexpected GeoNames country code "
                            f"{city.country_code!r} at line {line_number}."
                        )

                    excluded_by_reason["unsupported_country"] += 1
                    excluded_by_country[city.country_code] += 1
                    continue

                accepted.append(city)

    accepted.sort(key=lambda city: city.id)

    output.parent.mkdir(parents=True, exist_ok=True)

    temporary_path = None

    try:
        with tempfile.NamedTemporaryFile(
            dir=output.parent,
            prefix=f".{output.name}.",
            suffix=".tmp",
            delete=False,
        ) as temporary_file:
            temporary_path = Path(temporary_file.name)

        with zipfile.ZipFile(
            temporary_path,
            mode="w",
            compression=zipfile.ZIP_DEFLATED,
            compresslevel=9,
        ) as archive:
            buffer = io.StringIO(newline="")
            writer = csv.writer(buffer, lineterminator="\n")

            writer.writerow(FIELD_NAMES)

            for city in accepted:
                writer.writerow(
                    (
                        city.id,
                        city.country_code,
                        city.name,
                        city.ascii_name or "",
                        city.latitude,
                        city.longitude,
                        "" if city.population is None else city.population,
                        city.feature_code,
                    )
                )

            info = zipfile.ZipInfo(
                filename="cities1000.csv",
                date_time=(1980, 1, 1, 0, 0, 0),
            )
            info.compress_type = zipfile.ZIP_DEFLATED
            info._compresslevel = 9

            archive.writestr(info, buffer.getvalue().encode("utf-8"))

        os.replace(temporary_path, output)

    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)

    return PreparationReport(
        total=total,
        accepted=len(accepted),
        excluded=sum(excluded_by_reason.values()),
        excluded_by_reason=dict(sorted(excluded_by_reason.items())),
        excluded_by_country=dict(sorted(excluded_by_country.items())),
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Prepare BeenAround cities from GeoNames cities1000."
    )
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--countries", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)

    args = parser.parse_args()

    report = prepare_cities(
        source=args.source,
        countries_path=args.countries,
        output=args.output,
    )

    print(
        json.dumps(
            {
                "total": report.total,
                "accepted": report.accepted,
                "excluded": report.excluded,
                "excluded_by_reason": report.excluded_by_reason,
                "excluded_by_country": report.excluded_by_country,
            },
            indent=2,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
