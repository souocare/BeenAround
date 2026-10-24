"""Create city visits table.

Revision ID: 644e0de73360
Revises: 710fe5233eba
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "644e0de73360"
down_revision: Union[str, Sequence[str], None] = "710fe5233eba"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "city_visits",
        sa.Column(
            "id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.Uuid(),
            nullable=False,
        ),
        sa.Column(
            "city_id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "started_on",
            sa.Date(),
            nullable=True,
        ),
        sa.Column(
            "ended_on",
            sa.Date(),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.CheckConstraint(
            "ended_on IS NULL OR (started_on IS NOT NULL AND ended_on >= started_on)",
            name="ck_city_visits_valid_dates",
        ),
        sa.ForeignKeyConstraint(
            ["city_id"],
            ["cities.id"],
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index(
        "ix_city_visits_user_city",
        "city_visits",
        ["user_id", "city_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_city_visits_user_city",
        table_name="city_visits",
    )

    op.drop_table("city_visits")
