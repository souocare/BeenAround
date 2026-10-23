"""Generate continent metadata for the versioned country catalog."""

import json
from pathlib import Path

import country_converter as coco
import pandas as pd

CATALOG_PATH = Path(__file__).resolve().parents[1] / "app/data/countries.json"

VALID_CONTINENTS = {
    "Africa",
    "Antarctica",
    "Asia",
    "Europe",
    "North America",
    "South America",
    "Oceania",
}

# BeenAround's explicit geographical conventions.
# BeenAround's explicit geographical conventions and ISO2 exceptions.
OVERRIDES = {
    "AQ": "Antarctica",
    "RU": "Europe",
    "TR": "Asia",
    "KZ": "Asia",
    "GE": "Asia",
    "AZ": "Asia",
    "GB": "Europe",
    "GR": "Europe",
}


def main() -> None:
    countries = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))

    reference = pd.read_csv(
        coco.country_converter.COUNTRY_DATA_FILE,
        sep="\t",
        encoding="utf-8",
        dtype=str,
        keep_default_na=False,
    )

    reference["ISO2"] = reference["ISO2"].str.strip()

    # Build a direct ISO2 lookup.
    lookup = {}

    for _, row in reference.iterrows():
        iso2 = row["ISO2"]

        if len(iso2) != 2:
            continue

        lookup[iso2] = {
            "continent": row["continent"],
            "region": row["UNregion"],
        }

    unresolved = []

    for country in countries:
        code = country["code"]

        if code in OVERRIDES:
            continent = OVERRIDES[code]
        else:
            metadata = lookup.get(code)

            if metadata is None:
                unresolved.append((code, country["name"], "Missing ISO2"))
                continue

            continent = metadata["continent"]

            if continent == "America":
                region = metadata["region"]

                if region in {
                    "Northern America",
                    "Central America",
                    "Caribbean",
                }:
                    continent = "North America"
                elif region == "South America":
                    continent = "South America"

        if continent not in VALID_CONTINENTS:
            unresolved.append((code, country["name"], continent))
            continue

        country["continent"] = continent

    if unresolved:
        print("Countries requiring explicit classification:")

        for code, name, reason in unresolved:
            print(f"  {code}: {name} ({reason})")

        raise SystemExit(
            f"{len(unresolved)} countries remain unclassified."
        )

    if len(countries) != 249:
        raise SystemExit(
            f"Expected 249 countries, found {len(countries)}."
        )

    CATALOG_PATH.write_text(
        json.dumps(countries, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"Successfully classified {len(countries)} countries.")


if __name__ == "__main__":
    main()