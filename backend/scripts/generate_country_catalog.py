"""Generate BeenAround's versioned ISO 3166-1 country catalog."""

import json
from pathlib import Path

import pycountry

OUTPUT_PATH = Path(__file__).resolve().parents[1] / "app" / "data" / "countries.json"


def main() -> None:
    countries = [
        {
            "code": country.alpha_2,
            "alpha3_code": country.alpha_3,
            "name": country.name,
        }
        for country in pycountry.countries
    ]

    countries.sort(key=lambda country: country["code"])

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    OUTPUT_PATH.write_text(
        json.dumps(
            countries,
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    print(f"Generated {len(countries)} countries: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
