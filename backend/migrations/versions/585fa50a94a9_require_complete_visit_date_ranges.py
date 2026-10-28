"""require complete visit date ranges

Revision ID: 585fa50a94a9
Revises: 4bd62fcb5448
Create Date: 2026-10-28 00:52:46.775642

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '585fa50a94a9'
down_revision: Union[str, Sequence[str], None] = '4bd62fcb5448'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None



TABLES = (
    "country_visits",
    "city_visits",
)


def _ensure_complete_visits() -> None:
    """Abort before schema changes if any visit has incomplete dates."""

    connection = op.get_bind()

    for table in TABLES:
        incomplete = connection.execute(
            sa.text(
                f"""
                SELECT COUNT(*)
                FROM {table}
                WHERE started_on IS NULL
                   OR ended_on IS NULL
                   OR started_on_precision IS NULL
                   OR ended_on_precision IS NULL
                """
            )
        ).scalar_one()

        if incomplete:
            raise RuntimeError(
                f"Cannot require complete visit dates: "
                f"{table} contains {incomplete} incomplete visit(s). "
                "Complete their dates before running this migration."
            )


def upgrade() -> None:
    """Require start/end dates and precisions without changing visit data."""

    # Check both tables before modifying either one.
    _ensure_complete_visits()

    for table in TABLES:
        with op.batch_alter_table(table) as batch_op:
            batch_op.alter_column(
                "started_on",
                existing_type=sa.Date(),
                existing_nullable=True,
                nullable=False,
            )

            batch_op.alter_column(
                "ended_on",
                existing_type=sa.Date(),
                existing_nullable=True,
                nullable=False,
            )

            batch_op.alter_column(
                "started_on_precision",
                existing_type=sa.String(length=5),
                existing_nullable=True,
                nullable=False,
            )

            batch_op.alter_column(
                "ended_on_precision",
                existing_type=sa.String(length=5),
                existing_nullable=True,
                nullable=False,
            )


def downgrade() -> None:
    """Restore nullable visit dates without modifying existing records."""

    for table in reversed(TABLES):
        with op.batch_alter_table(table) as batch_op:
            batch_op.alter_column(
                "started_on",
                existing_type=sa.Date(),
                existing_nullable=False,
                nullable=True,
            )

            batch_op.alter_column(
                "ended_on",
                existing_type=sa.Date(),
                existing_nullable=False,
                nullable=True,
            )

            batch_op.alter_column(
                "started_on_precision",
                existing_type=sa.String(length=5),
                existing_nullable=False,
                nullable=True,
            )

            batch_op.alter_column(
                "ended_on_precision",
                existing_type=sa.String(length=5),
                existing_nullable=False,
                nullable=True,
            )

