import json
from pathlib import Path

import shapefile


BACKEND_ROOT = Path(__file__).resolve().parents[2]

CATALOG_PATH = BACKEND_ROOT / "app/data/countries.json"

SHAPEFILE_PATH = BACKEND_ROOT / "data/geography/source/ne_10m_admin_0_map_units.shp"


def main() -> None:
    countries = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))

    catalog_codes = {country["code"] for country in countries}

    with shapefile.Reader(str(SHAPEFILE_PATH)) as reader:
        fields = [field[0] for field in reader.fields if field[0] != "DeletionFlag"]

        print("Dataset records:", len(reader))
        print()
        print("Available fields:")
        print(", ".join(fields))
        print()

        candidate_fields = [
            field
            for field in (
                "ISO_A2",
                "ISO_A2_EH",
                "ISO_A2_EH_",
                "WB_A2",
                "ADM0_A3",
                "GU_A3",
                "NAME",
                "NAME_EN",
            )
            if field in fields
        ]

        print("Candidate fields:")
        print(", ".join(candidate_fields))
        print()

        records = list(reader.iterRecords())

        for field in candidate_fields:
            if field not in {"ISO_A2", "ISO_A2_EH", "ISO_A2_EH_", "WB_A2"}:
                continue

            dataset_codes = {
                str(record[field]).upper()
                for record in records
                if isinstance(record[field], str)
                and len(record[field]) == 2
                and record[field] != "-99"
            }

            matched = catalog_codes & dataset_codes
            missing = catalog_codes - dataset_codes

            print(f"Field: {field}")
            print(f"Matched: {len(matched)}/{len(catalog_codes)}")
            print(f"Missing: {len(missing)}")
            print(", ".join(sorted(missing)))
            print()


if __name__ == "__main__":
    main()
