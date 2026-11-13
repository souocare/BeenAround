"""add trip flight associations

Revision ID: 704360cdf309
Revises: 066bcad5770e
Create Date: 2026-11-13 15:05:05.459308

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '704360cdf309'
down_revision: Union[str, Sequence[str], None] = '066bcad5770e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create associations between Trips and personal flights."""

    op.create_table(
        "trip_flights",
        sa.Column("trip_id", sa.Uuid(), nullable=False),
        sa.Column("flight_id", sa.Uuid(), nullable=False),
        sa.ForeignKeyConstraint(
            ["trip_id"],
            ["trips.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["flight_id"],
            ["flights.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "trip_id",
            "flight_id",
        ),
    )

    op.create_index(
        "ix_trip_flights_flight_id",
        "trip_flights",
        ["flight_id"],
        unique=False,
    )


def downgrade() -> None:
    """Remove Trip–Flight associations."""

    op.drop_index(
        "ix_trip_flights_flight_id",
        table_name="trip_flights",
    )

    op.drop_table("trip_flights")
