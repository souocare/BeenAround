"""add airport timezone identifiers

Revision ID: 066bcad5770e
Revises: f0b236f889b4
Create Date: 2026-11-13 11:22:31.201964

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '066bcad5770e'
down_revision: Union[str, Sequence[str], None] = 'f0b236f889b4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add optional IANA timezone identifiers to airports."""
    op.add_column(
        "airports",
        sa.Column(
            "timezone_id",
            sa.String(length=64),
            nullable=True,
        ),
    )


def downgrade() -> None:
    """Remove airport timezone identifiers."""
    op.drop_column("airports", "timezone_id")
