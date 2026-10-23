import json
from collections import Counter
from pathlib import Path

import shapefile

from scripts.geography.country_mapping import resolve_country_code


BACKEND_ROOT = Path(__file__).resolve().parents[2]

CATALOG_PATH = BACKEND_ROOT / "app/data/countries.json"

SHAPEFILE_PATH = (
    BACKEND_ROOT
    / "data/geography/source/ne_10m_admin_0_map_units.shp"
)


def main() -> None:
    countries = json.loads(
        CATALOG_PATH.read_text(encoding="utf-8")
    )

    catalog_codes = {
        country["code"]
        for country in countries
    }

    counts = Counter()

    with shapefile.Reader(str(SHAPEFILE_PATH)) as reader:
        for record in reader.iterShapeRecords():
            properties = record.record.as_dict()

            code = resolve_country_code(properties)

            if code in catalog_codes and record.shape.points:
                counts[code] += 1

    missing = sorted(catalog_codes - counts.keys())

    print(f"Catalog countries: {len(catalog_codes)}")
    print(f"Countries with geometry: {len(counts)}")
    print(f"Missing countries: {missing}")

    if missing:
        raise SystemExit(1)

    print("All catalog countries have mapped geometries.")


if __name__ == "__main__":
    main()