"""Split optimized Natural Earth GeoJSON into individual country assets."""

import json
from pathlib import Path


BACKEND_ROOT = Path(__file__).resolve().parents[2]
PROJECT_ROOT = BACKEND_ROOT.parent

SOURCE_PATH = (
    PROJECT_ROOT
    / "frontend/assets/geo/countries_detailed_optimized.geojson"
)

OUTPUT_DIR = (
    PROJECT_ROOT
    / "frontend/assets/geo/countries"
)


def main() -> None:
    collection = json.loads(
        SOURCE_PATH.read_text(encoding="utf-8")
    )

    features = collection["features"]

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    generated_codes = set()

    for feature in features:
        code = feature["properties"]["country_code"]

        if code in generated_codes:
            raise ValueError(f"Duplicate country code: {code}")

        generated_codes.add(code)

        country_collection = {
            "type": "FeatureCollection",
            "features": [feature],
        }

        output_path = OUTPUT_DIR / f"{code}.geojson"

        output_path.write_text(
            json.dumps(
                country_collection,
                ensure_ascii=False,
                separators=(",", ":"),
            ),
            encoding="utf-8",
        )

    if len(generated_codes) != 249:
        raise ValueError(
            f"Expected 249 countries, found {len(generated_codes)}"
        )

    total_bytes = sum(
        path.stat().st_size
        for path in OUTPUT_DIR.glob("*.geojson")
    )

    print(f"Generated countries: {len(generated_codes)}")
    print(f"Output directory: {OUTPUT_DIR}")
    print(f"Total size: {total_bytes / 1024 / 1024:.2f} MB")

    print()
    print("Example file sizes:")

    for code in ("PT", "ES", "US", "LK", "MV", "MT", "SG", "UM"):
        path = OUTPUT_DIR / f"{code}.geojson"

        print(f"{code}: {path.stat().st_size / 1024:.1f} KB")


if __name__ == "__main__":
    main()