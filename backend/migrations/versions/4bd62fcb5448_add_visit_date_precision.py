"""Add temporal precision to country and city visits.

Revision ID: 4bd62fcb5448
Revises: 644e0de73360
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

from app.domain.visit_date_constraints import (
    precision_check,
    range_check,
)


revision: str = "4bd62fcb5448"
down_revision: str | Sequence[str] | None = "644e0de73360"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


TABLES = (
    "country_visits",
    "city_visits",
)


def upgrade() -> None:
    """Add precision fields and preserve existing exact dates."""

    for table in TABLES:
        op.add_column(
            table,
            sa.Column(
                "started_on_precision",
                sa.String(length=5),
                nullable=True,
            ),
        )

        op.add_column(
            table,
            sa.Column(
                "ended_on_precision",
                sa.String(length=5),
                nullable=True,
            ),
        )

        # All existing non-null dates represent exact dates.
        op.execute(
            sa.text(
                f"""
                UPDATE {table}
                SET started_on_precision = 'day'
                WHERE started_on IS NOT NULL
                """
            )
        )

        op.execute(
            sa.text(
                f"""
                UPDATE {table}
                SET ended_on_precision = 'day'
                WHERE ended_on IS NOT NULL
                """
            )
        )

        # SQLite requires batch operations to replace CHECK constraints.
        with op.batch_alter_table(table) as batch_op:
            batch_op.drop_constraint(
                f"ck_{table}_valid_dates",
                type_="check",
            )

            batch_op.create_check_constraint(
                f"ck_{table}_start_precision",
                precision_check(
                    "started_on",
                    "started_on_precision",
                ),
            )

            batch_op.create_check_constraint(
                f"ck_{table}_end_precision",
                precision_check(
                    "ended_on",
                    "ended_on_precision",
                ),
            )

            batch_op.create_check_constraint(
                f"ck_{table}_valid_dates",
                range_check(),
            )


def downgrade() -> None:
    """Restore exact-date storage, converting partial end dates safely."""

    for table in reversed(TABLES):
        # First remove the precision constraints.
        #
        # SQLite cannot drop CHECK constraints directly, so Alembic
        # recreates the table using batch operations.
        with op.batch_alter_table(table) as batch_op:
            batch_op.drop_constraint(
                f"ck_{table}_start_precision",
                type_="check",
            )

            batch_op.drop_constraint(
                f"ck_{table}_end_precision",
                type_="check",
            )

            batch_op.drop_constraint(
                f"ck_{table}_valid_dates",
                type_="check",
            )

        # Convert partial end dates to the latest possible day.
        #
        # Example:
        #   2024-08-01 (month) -> 2024-08-31
        #
        # This conversion loses precision information.
        op.execute(
            sa.text(
                f"""
                UPDATE {table}
                SET ended_on =
                    CASE ended_on_precision
                        WHEN 'month'
                            THEN date(
                                ended_on,
                                'start of month',
                                '+1 month',
                                '-1 day'
                            )
                        WHEN 'year'
                            THEN date(
                                ended_on,
                                'start of year',
                                '+1 year',
                                '-1 day'
                            )
                        ELSE ended_on
                    END
                WHERE ended_on IS NOT NULL
                """
            )
        )

        # Restore the original schema and chronological constraint.
        with op.batch_alter_table(table) as batch_op:
            batch_op.create_check_constraint(
                f"ck_{table}_valid_dates",
                (
                    "ended_on IS NULL OR "
                    "(started_on IS NOT NULL AND ended_on >= started_on)"
                ),
            )

            batch_op.drop_column("ended_on_precision")
            batch_op.drop_column("started_on_precision")