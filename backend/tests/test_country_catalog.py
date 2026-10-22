"""Tests for the versioned ISO 3166-1 country catalog."""

import ast
import json
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session

from app.models.country import Country

BACKEND_ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = BACKEND_ROOT / "app" / "data" / "countries.json"


def load_catalog() -> list[dict[str, str]]:
    """Load the versioned country catalog."""
    return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))


def test_country_catalog_contains_249_entries() -> None:
    countries = load_catalog()

    assert len(countries) == 249


def test_country_catalog_identifiers_are_unique() -> None:
    countries = load_catalog()

    alpha2_codes = [country["code"] for country in countries]
    alpha3_codes = [country["alpha3_code"] for country in countries]

    assert len(alpha2_codes) == len(set(alpha2_codes))
    assert len(alpha3_codes) == len(set(alpha3_codes))


def test_country_catalog_entries_are_valid() -> None:
    countries = load_catalog()

    for country in countries:
        assert set(country) == {
            "code",
            "name",
            "alpha3_code",
        }

        assert len(country["code"]) == 2
        assert len(country["alpha3_code"]) == 3
        assert country["name"].strip()


@pytest.fixture
def migrated_database(tmp_path: Path, monkeypatch):
    """Create an isolated database using the complete Alembic history."""

    database_path = tmp_path / "country_catalog_test.db"
    database_url = f"sqlite:///{database_path}"

    monkeypatch.setenv(
        "BEENAROUND_DATABASE_URL",
        database_url,
    )

    from app.core.config import get_settings

    get_settings.cache_clear()

    config = Config(str(BACKEND_ROOT / "alembic.ini"))
    config.set_main_option(
        "script_location",
        str(BACKEND_ROOT / "migrations"),
    )

    try:
        command.upgrade(config, "head")

        engine = create_engine(database_url)

        try:
            yield engine
        finally:
            engine.dispose()
    finally:
        get_settings.cache_clear()


def test_fresh_database_contains_full_country_catalog(
    migrated_database,
) -> None:
    """A fresh installation must receive the complete catalog."""

    with Session(migrated_database) as session:
        count = session.scalar(select(func.count()).select_from(Country))

        assert count == 249


def test_migrated_countries_match_versioned_catalog(
    migrated_database,
) -> None:
    """Database records must match the versioned source catalog."""

    expected = {
        country["code"]: (
            country["name"],
            country["alpha3_code"],
        )
        for country in load_catalog()
    }

    with Session(migrated_database) as session:
        persisted = {
            country.code: (
                country.name,
                country.alpha3_code,
            )
            for country in session.scalars(select(Country))
        }

    assert persisted == expected


@pytest.mark.parametrize(
    ("code", "expected_name", "expected_alpha3"),
    [
        ("PT", "Portugal", "PRT"),
        ("ES", "Spain", "ESP"),
        ("LK", "Sri Lanka", "LKA"),
        ("MV", "Maldives", "MDV"),
        ("GB", "United Kingdom", "GBR"),
        ("GI", "Gibraltar", "GIB"),
        ("HK", "Hong Kong", "HKG"),
    ],
)
def test_important_countries_exist(
    migrated_database,
    code,
    expected_name,
    expected_alpha3,
) -> None:
    with Session(migrated_database) as session:
        country = session.get(Country, code)

        assert country is not None
        assert country.name == expected_name
        assert country.alpha3_code == expected_alpha3


def test_initial_migration_snapshot_matches_catalog() -> None:
    """The initial migration snapshot must match the versioned catalog."""

    migration_path = (
        BACKEND_ROOT / "migrations" / "versions" / "207072e16da8_seed_country_catalog.py"
    )

    tree = ast.parse(migration_path.read_text(encoding="utf-8"))

    assignment = next(
        node
        for node in tree.body
        if isinstance(node, ast.Assign)
        and any(
            isinstance(target, ast.Name) and target.id == "COUNTRIES" for target in node.targets
        )
    )

    snapshot = ast.literal_eval(assignment.value)

    expected = tuple(
        (
            country["code"],
            country["name"],
            country["alpha3_code"],
        )
        for country in load_catalog()
    )

    assert len(snapshot) == 249
    assert snapshot == expected
