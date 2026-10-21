# BeenAround Country Catalog

## Purpose

BeenAround maintains a local, versioned geographic reference catalog.

The catalog provides stable country identifiers for travel history,
country visits, future city records, map rendering, and statistics.

Runtime access to an external country API is not required.

## Source

- Standard: ISO 3166-1
- Source library: pycountry
- Source version: 26.2.16
- Source license: LGPL-2.1-only
- Generated: 2026-10-21
- Entries: 249

The catalog includes countries and territories with ISO 3166-1 codes.

## Identifiers

Each entry contains:

- `code`: ISO 3166-1 alpha-2.
- `alpha3_code`: ISO 3166-1 alpha-3.
- `name`: Country or territory name provided by the source.

Alpha-2 is the canonical database identifier.

Alpha-3 is retained for interoperability with geographic datasets.

## Generation

The catalog is generated using:

```bash
pip install pycountry==26.2.16
python scripts/generate_country_catalog.py
```

The generated JSON is committed to the repository.

The application does not require pycountry at runtime.

## Database
The country catalog is seeded through a versioned Alembic data migration.

The migration contains a snapshot of the catalog rather than loading
the current JSON file at migration time.

This ensures that historical migrations remain reproducible.

## Important considerations

ISO 3166-1 includes countries and dependent territories.

The catalog must not be interpreted as a list of sovereign states.

Geographic and political classifications will be introduced separately
when implementing geographic statistics.

Country identifiers must remain stable once referenced by user records.

Natural Earth identifiers do not always match ISO alpha-3 codes.
Map integration must explicitly handle identifier differences.

Future catalog updates must be reviewed and applied through new,
versioned migrations rather than silently replacing existing records.