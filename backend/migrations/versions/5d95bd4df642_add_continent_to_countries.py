"""add continent to countries

Revision ID: 5d95bd4df642
Revises: 207072e16da8
Create Date: 2026-10-22 20:42:49.658962

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "5d95bd4df642"
down_revision: Union[str, Sequence[str], None] = "207072e16da8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# Immutable geographical classification snapshot.
# Generated from the validated 249-entry country catalog.
CONTINENT_CODES = {
    "Africa": (
        "AO",
        "BF",
        "BI",
        "BJ",
        "BW",
        "CD",
        "CF",
        "CG",
        "CI",
        "CM",
        "CV",
        "DJ",
        "DZ",
        "EG",
        "EH",
        "ER",
        "ET",
        "GA",
        "GH",
        "GM",
        "GN",
        "GQ",
        "GW",
        "IO",
        "KE",
        "KM",
        "LR",
        "LS",
        "LY",
        "MA",
        "MG",
        "ML",
        "MR",
        "MU",
        "MW",
        "MZ",
        "NA",
        "NE",
        "NG",
        "RE",
        "RW",
        "SC",
        "SD",
        "SH",
        "SL",
        "SN",
        "SO",
        "SS",
        "ST",
        "SZ",
        "TD",
        "TF",
        "TG",
        "TN",
        "TZ",
        "UG",
        "YT",
        "ZA",
        "ZM",
        "ZW",
    ),
    "Antarctica": ("AQ", "BV", "GS", "HM"),
    "Asia": (
        "AE",
        "AF",
        "AM",
        "AZ",
        "BD",
        "BH",
        "BN",
        "BT",
        "CC",
        "CN",
        "CX",
        "CY",
        "GE",
        "HK",
        "ID",
        "IL",
        "IN",
        "IQ",
        "IR",
        "JO",
        "JP",
        "KG",
        "KH",
        "KP",
        "KR",
        "KW",
        "KZ",
        "LA",
        "LB",
        "LK",
        "MM",
        "MN",
        "MO",
        "MV",
        "MY",
        "NP",
        "OM",
        "PH",
        "PK",
        "PS",
        "QA",
        "SA",
        "SG",
        "SY",
        "TH",
        "TJ",
        "TL",
        "TM",
        "TR",
        "TW",
        "UZ",
        "VN",
        "YE",
    ),
    "Europe": (
        "AD",
        "AL",
        "AT",
        "AX",
        "BA",
        "BE",
        "BG",
        "BY",
        "CH",
        "CZ",
        "DE",
        "DK",
        "EE",
        "ES",
        "FI",
        "FO",
        "FR",
        "GB",
        "GG",
        "GI",
        "GR",
        "HR",
        "HU",
        "IE",
        "IM",
        "IS",
        "IT",
        "JE",
        "LI",
        "LT",
        "LU",
        "LV",
        "MC",
        "MD",
        "ME",
        "MK",
        "MT",
        "NL",
        "NO",
        "PL",
        "PT",
        "RO",
        "RS",
        "RU",
        "SE",
        "SI",
        "SJ",
        "SK",
        "SM",
        "UA",
        "VA",
    ),
    "North America": (
        "AG",
        "AI",
        "AW",
        "BB",
        "BL",
        "BM",
        "BQ",
        "BS",
        "BZ",
        "CA",
        "CR",
        "CU",
        "CW",
        "DM",
        "DO",
        "GD",
        "GL",
        "GP",
        "GT",
        "HN",
        "HT",
        "JM",
        "KN",
        "KY",
        "LC",
        "MF",
        "MQ",
        "MS",
        "MX",
        "NI",
        "PA",
        "PM",
        "PR",
        "SV",
        "SX",
        "TC",
        "TT",
        "US",
        "VC",
        "VG",
        "VI",
    ),
    "Oceania": (
        "AS",
        "AU",
        "CK",
        "FJ",
        "FM",
        "GU",
        "KI",
        "MH",
        "MP",
        "NC",
        "NF",
        "NR",
        "NU",
        "NZ",
        "PF",
        "PG",
        "PN",
        "PW",
        "SB",
        "TK",
        "TO",
        "TV",
        "UM",
        "VU",
        "WF",
        "WS",
    ),
    "South America": (
        "AR",
        "BO",
        "BR",
        "CL",
        "CO",
        "EC",
        "FK",
        "GF",
        "GY",
        "PE",
        "PY",
        "SR",
        "UY",
        "VE",
    ),
}


def upgrade() -> None:
    """Add continent metadata to the country catalog."""

    with op.batch_alter_table("countries") as batch_op:
        batch_op.add_column(
            sa.Column(
                "continent",
                sa.String(length=20),
                nullable=True,
            )
        )

        connection = op.get_bind()

    countries = sa.table(
        "countries",
        sa.column("code", sa.String(length=2)),
        sa.column("continent", sa.String(length=20)),
    )

    # Validate the immutable snapshot before modifying existing records.
    continent_by_code = {}

    for continent, codes in CONTINENT_CODES.items():
        for code in codes:
            if code in continent_by_code:
                raise RuntimeError(f"Duplicate country code in continent snapshot: {code}")

            continent_by_code[code] = continent

    if len(continent_by_code) != 249:
        raise RuntimeError(
            f"Expected exactly 249 countries in continent snapshot, found {len(continent_by_code)}."
        )

    existing_codes = set(connection.execute(sa.select(countries.c.code)).scalars())

    snapshot_codes = set(continent_by_code)

    if existing_codes != snapshot_codes:
        missing = sorted(existing_codes - snapshot_codes)
        unexpected = sorted(snapshot_codes - existing_codes)

        raise RuntimeError(
            "Country catalog does not match continent snapshot. "
            f"Missing classifications: {missing}. "
            f"Snapshot-only countries: {unexpected}."
        )

    for code, continent in continent_by_code.items():
        connection.execute(
            countries.update().where(countries.c.code == code).values(continent=continent)
        )

    unclassified = connection.execute(
        sa.select(sa.func.count()).select_from(countries).where(countries.c.continent.is_(None))
    ).scalar_one()

    if unclassified:
        raise RuntimeError(f"{unclassified} countries remain without a continent.")

    with op.batch_alter_table("countries") as batch_op:
        batch_op.alter_column(
            "continent",
            existing_type=sa.String(length=20),
            nullable=False,
        )


def downgrade() -> None:
    """Remove continent metadata."""

    with op.batch_alter_table("countries") as batch_op:
        batch_op.drop_column("continent")
