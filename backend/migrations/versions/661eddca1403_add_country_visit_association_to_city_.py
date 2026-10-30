"""add country visit association to city visits

Revision ID: 661eddca1403
Revises: 585fa50a94a9
Create Date: 2026-10-30 00:47:32.045309

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '661eddca1403'
down_revision: Union[str, Sequence[str], None] = '585fa50a94a9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Allow city visits to reference an optional country visit."""

    with op.batch_alter_table("city_visits") as batch_op:
        batch_op.add_column(
            sa.Column(
                "country_visit_id",
                sa.Uuid(),
                nullable=True,
            )
        )

        batch_op.create_foreign_key(
            "fk_city_visits_country_visit_id",
            "country_visits",
            ["country_visit_id"],
            ["id"],
            ondelete="SET NULL",
        )

        batch_op.create_index(
            "ix_city_visits_country_visit_id",
            ["country_visit_id"],
        )


def downgrade() -> None:
    """Remove the optional country visit association."""

    with op.batch_alter_table("city_visits") as batch_op:
        batch_op.drop_index(
            "ix_city_visits_country_visit_id",
        )

        batch_op.drop_constraint(
            "fk_city_visits_country_visit_id",
            type_="foreignkey",
        )

        batch_op.drop_column("country_visit_id")