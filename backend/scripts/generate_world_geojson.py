#!/usr/bin/env python3
"""Generate BeenAround's world GeoJSON from Natural Earth data."""

import json
from pathlib import Path

import shapefile


BACKEND_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = BACKEND_ROOT.parent
FRONTEND_ROOT = PROJECT_ROOT / "frontend"

SOURCE_PATH = (
    FRONTEND_ROOT
    / "assets/geo/source/ne_110m_admin_0_countries.shp"
)

CATALOG_PATH = BACKEND_ROOT / "app/data/countries.json"

OUTPUT_PATH = (
    FRONTEND_ROOT
    / "assets/geo/world_countries.geojson"
)


def load_country_catalog():
    """Return a mapping from ISO alpha-3 to ISO alpha-2."""
    with CATALOG_PATH.open(encoding="utf-8") as file:
        countries = json.load(file)

    return {
        country["alpha3_code"]: country["code"]
        for country in countries
    }


def resolve_country_code(properties, catalog):
    """Resolve a Natural Earth feature against the BeenAround catalog."""
    candidates = (
        properties.get("ISO_A3"),
        properties.get("ADM0_A3"),
    )

    for candidate in candidates:
        if candidate in catalog:
            return catalog[candidate]

    return None


def main():
    catalog = load_country_catalog()

    reader = shapefile.Reader(
        str(SOURCE_PATH),
        encoding="utf-8",
    )

    features = []
    unresolved = []

    for shape_record in reader.iterShapeRecords():
        properties = shape_record.record.as_dict()

        country_code = resolve_country_code(properties, catalog)

        if country_code is None:
            unresolved.append(
                {
                    "name": properties.get("ADMIN"),
                    "iso_a3": properties.get("ISO_A3"),
                    "adm0_a3": properties.get("ADM0_A3"),
                }
            )

        geometry = shape_record.shape.__geo_interface__

        features.append(
            {
                "type": "Feature",
                "properties": {
                    "country_code": country_code,
                    "country_name": properties.get("ADMIN"),
                },
                "geometry": geometry,
            }
        )

    collection = {
        "type": "FeatureCollection",
        "features": features,
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    with OUTPUT_PATH.open("w", encoding="utf-8") as file:
        json.dump(
            collection,
            file,
            ensure_ascii=False,
            separators=(",", ":"),
        )

    print(f"Generated: {OUTPUT_PATH}")
    print(f"Total features: {len(features)}")
    print(f"Resolved: {len(features) - len(unresolved)}")
    print(f"Unresolved: {len(unresolved)}")

    if unresolved:
        print("\nUnresolved Natural Earth features:")

        for country in unresolved:
            print(
                f"  {country['name']}: "
                f"ISO_A3={country['iso_a3']}, "
                f"ADM0_A3={country['adm0_a3']}"
            )


if __name__ == "__main__":
    main()