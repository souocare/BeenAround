# BeenAround — Geographic Data Maintenance

## 1. Purpose

BeenAround uses locally bundled GeoJSON data to render country maps.

This document describes the geographic datasets, generation pipeline, update procedure, validation requirements, and maintenance considerations.

Geographic data updates must remain reproducible and must not modify personal travel records.

## 2. Geographic Data Architecture

The application maintains two different geographic representations.

### 2.1 Detailed country geometry

**Location**

```text
frontend/assets/geo/countries/
```

Contains individual GeoJSON files identified by ISO 3166-1 alpha-2 country codes.

Examples:

```text
PT.geojson
ES.geojson
NO.geojson
MV.geojson
```

**Purpose**
- Detailed rendering of selected countries.
- Coastlines, islands, and multipart geometries.
- Country-specific geographic bounds.
- Interactive Country Details maps.

The initial dataset contains 249 country/territory geometry files.

### 2.2 Simplified world geometry

**Location**

```text
frontend/assets/geo/world_countries.geojson
```

**Purpose**
- Geographic context surrounding the selected country.
- Neighboring countries and land boundaries.
- Lightweight background rendering.

The world geometry is deliberately less detailed than the individual country assets.

It must not be replaced automatically with the complete detailed dataset.

## 3. Geographic Source

The initial detailed country geometry is derived from:

**Natural Earth — 1:10m Admin 0 Map Units**

Natural Earth provides geographic boundary data suitable for cartographic visualization.

The country catalog and geographic polygons are separate datasets.

The country catalog uses ISO 3166-1 identifiers, while the geographic dataset requires explicit identifier mapping and validation.

### Important distinction

A country existing in the ISO catalog does not guarantee that the source geographic dataset represents it as a single matching feature.

Geographic features may require:
- Identifier normalization.
- Aggregation of multiple features.
- Handling of territories.
- Mapping of differing country codes.
- Validation of missing or duplicated geometry.

The mapping scripts must be used rather than assuming direct identifier compatibility.

## 4. Relevant Files

### Source data

```text
frontend/assets/geo/source/
```

Stores geographic source files used by the generation pipeline.

Source data should be retained when required to reproduce the bundled assets.

### Generation scripts

```text
backend/scripts/
├── generate_world_geojson.py
├── generate_country_continents.py
└── geography/
    ├── country_mapping.py
    ├── inspect_dataset.py
    ├── inspect_geometry_mapping.py
    ├── prepare_countries.py
    ├── optimize_geojson.py
    ├── split_countries.py
    └── validate_mapping.py
```

### Geographic tests

```text
backend/tests/geography/
```

### Flutter geometry tests

```text
frontend/test/features/map/
```

## 5. Detailed Country Geometry Pipeline

The detailed country geometry pipeline consists of three main transformations.

### Step 1 — Prepare country geometry

Script:

```text
backend/scripts/geography/prepare_countries.py
```

Produces:

```text
frontend/assets/geo/countries_detailed.geojson
```

This stage prepares detailed country geometry using the source dataset and country mapping logic.

### Step 2 — Optimize geometry

Script:

```text
backend/scripts/geography/optimize_geojson.py
```

Input:

```text
frontend/assets/geo/countries_detailed.geojson
```

Output:

```text
frontend/assets/geo/countries_detailed_optimized.geojson
```

The optimized representation reduces the amount of geographic data required for application assets.

### Step 3 — Split country geometry

Script:

```text
backend/scripts/geography/split_countries.py
```

Input:

```text
frontend/assets/geo/countries_detailed_optimized.geojson
```

Output directory:

```text
frontend/assets/geo/countries/
```

Produces individual GeoJSON assets using country identifiers.

### Pipeline summary

```text
Natural Earth source
        |
        v
prepare_countries.py
        |
        v
countries_detailed.geojson
        |
        v
optimize_geojson.py
        |
        v
countries_detailed_optimized.geojson
        |
        v
split_countries.py
        |
        v
countries/{ISO2}.geojson
```

The two combined GeoJSON files are intermediate artifacts.

They do not need to remain in the repository after successful generation and validation.

## 6. Updating Detailed Country Geometry

### 6.1 Prepare the environment

Work from the backend directory.

Activate the existing Python virtual environment:

```bash
source .beenaroundvenv/bin/activate
```

Confirm the repository is clean before regenerating assets:

```bash
git status --short
```

### 6.2 Update the source dataset

Obtain the intended Natural Earth release.

Preserve the expected dataset structure and source-file locations.

Do not silently change the geographic dataset version or resolution.

Record:
- Dataset name.
- Dataset version or release date.
- Source URL.
- Download date.
- Relevant licensing or attribution information.

### 6.3 Inspect and validate the mapping

Review the geographic mapping and validation scripts:

```text
geography/country_mapping.py
geography/validate_mapping.py
geography/inspect_dataset.py
geography/inspect_geometry_mapping.py
```

Confirm that all expected ISO country codes can be resolved.

Investigate:
- Missing countries.
- Duplicate country codes.
- Unexpected territories.
- Invalid geometry.
- Unexpected geographic extents.

### 6.4 Run the generation pipeline

Run the scripts in this order:

```text
1. prepare_countries.py
2. optimize_geojson.py
3. split_countries.py
```

Execute them using their supported command-line interfaces and expected working directory.

**Before execution:** inspect each script's entry point to confirm whether it accepts command-line arguments or uses fixed repository-relative paths.

Do not assume that every script implements `--help` or accepts configurable input/output paths.

### 6.5 Validate the generated assets

Confirm:
- Expected country asset count.
- Expected ISO alpha-2 filenames.
- No missing required country geometry.
- Valid GeoJSON structure.
- Correct geometry types.
- Finite coordinate values.
- Reasonable geographic bounds.
- Acceptable asset sizes.
- Compatibility with the Flutter parser.

Compare the newly generated assets against the previous version.

Large unexpected changes should be investigated before committing.

### 6.6 Remove intermediate files

After successful generation and validation, the following files can be removed:

```text
frontend/assets/geo/countries_detailed.geojson
frontend/assets/geo/countries_detailed_optimized.geojson
```

Keep the individual country assets and required source data.

## 7. Updating World Context Geometry

The world context asset is generated separately.

Script:

```text
backend/scripts/generate_world_geojson.py
```

Output:

```text
frontend/assets/geo/world_countries.geojson
```

The world context should remain lightweight.

When regenerating:
1. Confirm the source dataset expected by the script.
2. Review its configuration and entry point.
3. Generate the world GeoJSON.
4. Validate its geometry.
5. Compare its size with the previous asset.
6. Check representative countries visually.
7. Run the Flutter geometry tests.

Do not assume that updating detailed country assets automatically updates the world context.

Both datasets must be maintained deliberately.

## 8. Country Continent Data

The repository also contains:

```text
backend/scripts/generate_country_continents.py
```

This script concerns geographic country/continent reference information.

It is separate from detailed country polygon generation.

Review its inputs, outputs, and intended consumers before including it in a geographic update.

Do not run it automatically as part of every polygon update unless the source or mapping data it depends on has changed.

## 9. Automated Validation

### Backend

Run from the backend directory:

```bash
ruff format --check scripts/geography tests/geography
ruff check scripts/geography tests/geography
python -m pytest -q tests/geography/
```

Include additional generation scripts in Ruff checks when modified.

### Flutter

Run from the frontend directory:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter test test/features/map/
flutter test test/features/explore/country_details_page_test.dart
flutter test
flutter analyze
```

Any analyzer diagnostics must be reviewed.

Existing unrelated warnings should be distinguished from newly introduced problems.

## 10. Visual Validation

After updating geographic assets, manually inspect representative countries.

Recommended regression set:

| Country | Validation target |
|---|---|
| Spain | Standard continental geography |
| Norway | High latitudes and complex coastline |
| Cabo Verde | Island archipelago |
| Greece | Mainland and numerous islands |
| Thailand | Elongated geography |
| Maldives | Very small islands and geographic extent |

Verify:
- Country geometry loads successfully.
- No native MapLibre crashes.
- Initial viewport is finite.
- Country boundaries render correctly.
- Surrounding geographic context is visible.
- Panning and zooming work.
- Recenter restores the initial viewport.
- The selected country uses the expected styling.

The Maldives may remain difficult to distinguish at the initial zoom because of its small island geometries.

This is a known rendering limitation, not necessarily a missing-data issue.

## 11. Updating a Single Country

If only one country's geographic representation needs improvement:

1. Identify the relevant ISO alpha-2 code.
2. Inspect the existing country GeoJSON.
3. Determine whether the problem originates in the source data, country mapping, optimization, or rendering.
4. Correct the appropriate pipeline stage.
5. Regenerate the affected data.
6. Validate the target country.
7. Check neighboring or related territories.
8. Run the relevant automated tests.

Prefer fixing the generation pipeline rather than manually editing a generated country asset.

Manual edits can be lost during regeneration and make the dataset difficult to reproduce.

If a country-specific correction is unavoidable, document it explicitly and implement it in the generation pipeline.

## 12. Repository and Release Considerations

Geographic source files and generated assets should be handled separately.

**Keep**
- Required source datasets.
- Reproducible generation scripts.
- Mapping definitions.
- Geographic validation tests.
- Runtime GeoJSON assets.

**Do not commit**
- Python `__pycache__` directories.
- `.pyc` files.
- Temporary inspection output.
- Unnecessary intermediate GeoJSON files.

Before committing:

```bash
git status --short
git diff --stat
git diff --check
```

Review changes to country counts, file sizes, and geographic coverage.

Commit geographic data updates separately from unrelated application changes.

## 13. Architectural Rules

- Country catalog identifiers remain stable.
- Geographic data updates must not alter user travel records.
- Geographic geometry is not the source of truth for visited status.
- Runtime maps use bundled geometry assets.
- Detailed and simplified world geometry remain separate.
- Country mapping must be explicit and validated.
- Generated assets should remain reproducible.
- Geographic data updates should not require database migrations unless reference-data contracts actually change.
- No country-specific camera workaround should be introduced without a demonstrated need.
- Privacy and user ownership rules remain independent of geographic visualization.

## 14. Known Limitations and Future Work

- Improve visibility of small islands at low zoom levels.
- Periodically review Natural Earth updates.
- Review geographic coverage when adding new territories to the country catalog.
- Consider automated asset-generation consistency checks.
- Evaluate data-size changes before introducing additional geographic layers.
- Extend geographic visualization to cities, airports, and flight routes in future milestones.


## Geographic Reference Data — Sources and Decisions

BeenAround maintains separate geographic reference datasets for countries, continents, cities, and map geometry.

These datasets are shared across users and remain independent of personal travel records.

### Country Catalog

**Source:** ISO 3166-1, through `pycountry` 26.2.16.

**Coverage:** 249 countries and territories.

**Storage:**
- `backend/app/data/countries.json`
- SQLite `countries` table.

**Identifiers:**
- ISO alpha-2: canonical primary key.
- ISO alpha-3: interoperability with geographic datasets.

**Generation:**
- `backend/scripts/generate_country_catalog.py`

**Database initialization:**
- Alembic migration `207072e16da8`.

The initial country catalog is stored as an immutable migration snapshot. Future changes require new versioned migrations.

### Continent Classification

**Coverage:** All 249 country catalog entries.

**Storage:** `countries.continent`.

**Generation and validation:**
- `backend/scripts/generate_country_continents.py`
- Alembic migration `5d95bd4df642`.

The migration contains a validated, immutable country-to-continent mapping.

Continent classification is geographic reference metadata and does not determine sovereignty.

### Country Map Geometry

**Source:** Natural Earth 1:10m Admin 0 Map Units.

**Storage:**
- `frontend/assets/geo/countries/{ISO2}.geojson`
- `frontend/assets/geo/world_countries.geojson`

Individual country assets provide detailed geographic geometry.

The simplified world asset provides lightweight surrounding geographic context.

**Generation:**
- `backend/scripts/geography/`
- `backend/scripts/generate_world_geojson.py`

Detailed geometry and simplified world geometry are maintained through separate generation pipelines.

### City Catalog

**Selected source:** GeoNames `cities1000`.

**Status:** Selected for M2.1; import pipeline not yet implemented.

**Intended coverage:** Worldwide populated places included in the GeoNames `cities1000` distribution.

**Planned information:**
- Stable GeoNames identifier.
- Primary city name.
- ASCII name.
- Country ISO alpha-2 code.
- Latitude and longitude.
- Population, when available.
- Support for alternative names in a later iteration.

**Storage:** Shared SQLite `cities` table.

**Import strategy:**
- Reproducible offline preparation and import.
- Dataset version and download date recorded.
- Validation against the existing country catalog.
- Idempotent imports.
- No external city API dependency at runtime.
- No large city dataset embedded directly in Alembic migrations.

**Important considerations:**
- GeoNames includes geographic feature classifications that must be handled explicitly.
- City records must reference valid country catalog entries.
- Missing or incompatible country identifiers must be reported rather than silently discarded.
- Dataset updates must preserve identifiers referenced by user visits.
- Catalog updates must not delete or invalidate personal travel history.
- GeoNames licensing and attribution requirements must be documented before distribution.

### General Data Principles

- Geographic reference data is shared across users.
- Personal visits remain private and user-owned.
- Country and city identifiers must remain stable.
- Geographic source datasets are versioned and documented.
- Data preparation happens outside application runtime.
- Runtime functionality must not depend on external geographic APIs.
- Reference data updates must be reproducible and validated.
- Updating geographic data must not silently modify personal travel records.