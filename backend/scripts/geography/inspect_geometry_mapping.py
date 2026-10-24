import json
from collections import defaultdict
from pathlib import Path

import shapefile


BACKEND_ROOT = Path(__file__).resolve().parents[2]

CATALOG_PATH = BACKEND_ROOT / "app/data/countries.json"

SHAPEFILE_PATH = BACKEND_ROOT / "data/geography/source/ne_10m_admin_0_map_units.shp"


def main() -> None:
    countries = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))

    catalog_codes = {country["code"] for country in countries}

    grouped = defaultdict(list)

    with shapefile.Reader(str(SHAPEFILE_PATH)) as reader:
        for record in reader.iterShapeRecords():
            properties = record.record.as_dict()

            code = properties.get("ISO_A2_EH")

            if not isinstance(code, str):
                continue

            code = code.strip().upper()

            if code not in catalog_codes:
                continue

            grouped[code].append(
                {
                    "name": properties.get("NAME"),
                    "geounit": properties.get("GEOUNIT"),
                    "type": properties.get("TYPE"),
                    "shape_type": record.shape.shapeTypeName,
                    "points": len(record.shape.points),
                }
            )

    print("Catalog countries:", len(catalog_codes))
    print("Countries with geometry:", len(grouped))
    print()

    missing = sorted(catalog_codes - grouped.keys())

    print("Missing countries:", missing)
    print()

    duplicates = {code: records for code, records in grouped.items() if len(records) > 1}

    print("Countries with multiple records:", len(duplicates))
    print()

    for code, records in sorted(duplicates.items()):
        print(f"{code}: {len(records)} records")

        for record in records:
            print(
                f"  - {record['name']} "
                f"| {record['geounit']} "
                f"| {record['type']} "
                f"| {record['shape_type']} "
                f"| {record['points']} points"
            )

    print()
    print("Sample countries:")

    for code in (
        "PT",
        "ES",
        "FR",
        "US",
        "GB",
        "LK",
        "MV",
        "MT",
        "SG",
        "UM",
    ):
        records = grouped.get(code, [])

        total_points = sum(record["points"] for record in records)

        print(f"{code}: {len(records)} records, {total_points} points")


if __name__ == "__main__":
    main()
