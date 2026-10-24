"""Generate BeenAround country geometries from Natural Earth map units."""

import json
from collections import defaultdict
from pathlib import Path

import shapefile

from scripts.geography.country_mapping import resolve_country_code


BACKEND_ROOT = Path(__file__).resolve().parents[2]
PROJECT_ROOT = BACKEND_ROOT.parent

CATALOG_PATH = BACKEND_ROOT / "app/data/countries.json"

SOURCE_PATH = BACKEND_ROOT / "data/geography/source/ne_10m_admin_0_map_units.shp"

OUTPUT_PATH = PROJECT_ROOT / "frontend/assets/geo/countries_detailed.geojson"


def extract_polygons(geometry: dict) -> list:
    """Extract polygon coordinates without discarding interior rings."""

    geometry_type = geometry["type"]
    coordinates = geometry["coordinates"]

    if geometry_type == "Polygon":
        return [coordinates]

    if geometry_type == "MultiPolygon":
        return coordinates

    raise ValueError(f"Unsupported geometry type: {geometry_type}")


def main() -> None:
    countries = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))

    catalog = {country["code"]: country for country in countries}

    grouped = defaultdict(list)

    with shapefile.Reader(str(SOURCE_PATH)) as reader:
        for shape_record in reader.iterShapeRecords():
            properties = shape_record.record.as_dict()

            code = resolve_country_code(properties)

            if code not in catalog:
                continue

            geometry = shape_record.shape.__geo_interface__

            grouped[code].extend(extract_polygons(geometry))

    missing = sorted(set(catalog) - set(grouped))

    if missing:
        raise ValueError(f"Missing country geometries: {', '.join(missing)}")

    features = []

    for code in sorted(catalog):
        polygons = grouped[code]

        geometry = (
            {
                "type": "Polygon",
                "coordinates": polygons[0],
            }
            if len(polygons) == 1
            else {
                "type": "MultiPolygon",
                "coordinates": polygons,
            }
        )

        features.append(
            {
                "type": "Feature",
                "properties": {
                    "country_code": code,
                    "country_name": catalog[code]["name"],
                },
                "geometry": geometry,
            }
        )

    collection = {
        "type": "FeatureCollection",
        "features": features,
    }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    OUTPUT_PATH.write_text(
        json.dumps(
            collection,
            ensure_ascii=False,
            separators=(",", ":"),
        ),
        encoding="utf-8",
    )

    size_mb = OUTPUT_PATH.stat().st_size / (1024 * 1024)

    print(f"Generated: {OUTPUT_PATH}")
    print(f"Countries: {len(features)}")
    print(f"File size: {size_mb:.2f} MB")


if __name__ == "__main__":
    main()
