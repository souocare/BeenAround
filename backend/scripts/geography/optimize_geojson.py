"""Optimize generated GeoJSON coordinate precision."""

import json
from pathlib import Path


BACKEND_ROOT = Path(__file__).resolve().parents[2]
PROJECT_ROOT = BACKEND_ROOT.parent

SOURCE_PATH = (
    PROJECT_ROOT
    / "frontend/assets/geo/countries_detailed.geojson"
)

OUTPUT_PATH = (
    PROJECT_ROOT
    / "frontend/assets/geo/countries_detailed_optimized.geojson"
)

DECIMAL_PLACES = 5


def round_coordinates(value):
    if isinstance(value, list):
        return [round_coordinates(item) for item in value]

    if isinstance(value, float):
        return round(value, DECIMAL_PLACES)

    return value


def main() -> None:
    collection = json.loads(
        SOURCE_PATH.read_text(encoding="utf-8")
    )

    for feature in collection["features"]:
        geometry = feature["geometry"]

        geometry["coordinates"] = round_coordinates(
            geometry["coordinates"]
        )

    OUTPUT_PATH.write_text(
        json.dumps(
            collection,
            ensure_ascii=False,
            separators=(",", ":"),
        ),
        encoding="utf-8",
    )

    original_size = SOURCE_PATH.stat().st_size
    optimized_size = OUTPUT_PATH.stat().st_size

    reduction = (
        1 - optimized_size / original_size
    ) * 100

    print(f"Original: {original_size / 1024 / 1024:.2f} MB")
    print(f"Optimized: {optimized_size / 1024 / 1024:.2f} MB")
    print(f"Reduction: {reduction:.1f}%")


if __name__ == "__main__":
    main()