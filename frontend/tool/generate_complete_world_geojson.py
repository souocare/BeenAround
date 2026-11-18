#!/usr/bin/env python3

"""Generate a world GeoJSON with complete catalog country coverage.

The original world GeoJSON is preserved.

Missing countries and territories are added from individual GeoJSON assets.

Run from the frontend directory:

    python3 tool/generate_complete_world_geojson.py
"""

import json
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

GEO_DIR = ROOT / "assets" / "geo"

WORLD_PATH = GEO_DIR / "world_countries.geojson"

COUNTRIES_DIR = GEO_DIR / "countries"

OUTPUT_PATH = GEO_DIR / "world_countries_complete.geojson"


def load_json(path: Path) -> dict:
    with path.open(encoding="utf-8") as file:
        return json.load(file)


def validate_feature(
    feature: dict,
    expected_code: str | None = None,
    allow_missing_code: bool = False,
) -> str | None:
    """Validate a geographic feature without changing its properties."""

    if feature.get("type") != "Feature":
        raise ValueError("Expected GeoJSON Feature")

    properties = feature.get("properties")

    if not isinstance(properties, dict):
        raise ValueError("Missing feature properties")

    code = properties.get("country_code")

    if not isinstance(code, str) or not code:
        if not allow_missing_code:
            raise ValueError("Missing country_code")

        code = None

    if expected_code is not None and code != expected_code:
        raise ValueError(
            f"Country code mismatch: expected {expected_code}, got {code}"
        )

    geometry = feature.get("geometry")

    if not isinstance(geometry, dict):
        raise ValueError(f"{code}: missing geometry")

    if geometry.get("type") not in ("Polygon", "MultiPolygon"):
        raise ValueError(
            f"{code}: unsupported geometry {geometry.get('type')}"
        )

    if not geometry.get("coordinates"):
        raise ValueError(f"{code}: empty coordinates")

    return code


def main() -> None:
    world = load_json(WORLD_PATH)

    if world.get("type") != "FeatureCollection":
        raise ValueError("World GeoJSON must be a FeatureCollection")

    original_features = world.get("features")

    if not isinstance(original_features, list):
        raise ValueError("World GeoJSON has invalid features")

    # Preserve all original world features.
    features = list(original_features)

    world_codes = {
        code
        for feature in features
        if (
            code := validate_feature(
                feature,
                allow_missing_code=True,
            )
        ) is not None
    }

    country_files = sorted(COUNTRIES_DIR.glob("*.geojson"))

    if not country_files:
        raise ValueError("No individual country geometries found")

    catalog_codes = {path.stem for path in country_files}

    missing_codes = sorted(catalog_codes - world_codes)

    print(f"Original world features: {len(features)}")
    print(f"Original country codes: {len(world_codes)}")
    print(f"Individual country files: {len(country_files)}")
    print(f"Missing country codes: {len(missing_codes)}")

    added_features = []

    for code in missing_codes:
        path = COUNTRIES_DIR / f"{code}.geojson"

        country = load_json(path)

        if country.get("type") != "FeatureCollection":
            raise ValueError(f"{code}: expected FeatureCollection")

        country_features = country.get("features")

        if not isinstance(country_features, list) or len(country_features) != 1:
            raise ValueError(
                f"{code}: expected exactly one geographic feature"
            )

        feature = country_features[0]

        validate_feature(feature, expected_code=code)

        added_features.append(feature)

    # Validate everything before writing.
    features.extend(added_features)

    generated_codes = {
        code
        for feature in features
        if (
            code := validate_feature(
                feature,
                allow_missing_code=True,
            )
        ) is not None
    }

    if not catalog_codes.issubset(generated_codes):
        missing = sorted(catalog_codes - generated_codes)
        raise ValueError(f"Incomplete country coverage: {missing}")

    if len(features) != len(original_features) + len(added_features):
        raise ValueError("Unexpected generated feature count")

    result = {
        "type": "FeatureCollection",
        "features": features,
    }

    # Deterministic output: same inputs produce identical output.
    encoded = json.dumps(
        result,
        ensure_ascii=False,
        separators=(",", ":"),
    )

    OUTPUT_PATH.write_text(encoded + "\n", encoding="utf-8")

    counts = Counter(
        code
        for feature in features
        if (
            code := feature["properties"].get("country_code")
        ) is not None
    )

    duplicated_codes = {
        code: count
        for code, count in counts.items()
        if count > 1
    }

    print()
    print("Generation completed")
    print("--------------------")
    print(f"Output: {OUTPUT_PATH.relative_to(ROOT)}")
    print(f"Original features: {len(original_features)}")
    print(f"Added features: {len(added_features)}")
    print(f"Total features: {len(features)}")
    print(f"Unique country codes: {len(generated_codes)}")
    print(f"Output size: {OUTPUT_PATH.stat().st_size / 1024 / 1024:.2f} MB")
    print(f"Codes with multiple features: {duplicated_codes}")


if __name__ == "__main__":
    main()