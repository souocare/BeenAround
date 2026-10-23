"""Add city feature code.

Revision ID: 710fe5233eba
Revises: f89381bd4034
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "710fe5233eba"
down_revision: Union[str, Sequence[str], None] = "f89381bd4034"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    connection = op.get_bind()

    existing_cities = connection.execute(
        sa.text("SELECT COUNT(*) FROM cities")
    ).scalar_one()

    if existing_cities:
        raise RuntimeError(
            "Cannot add required city feature_code: "
            "the cities table already contains records."
        )

    op.add_column(
        "cities",
        sa.Column(
            "feature_code",
            sa.String(length=10),
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_column("cities", "feature_code")