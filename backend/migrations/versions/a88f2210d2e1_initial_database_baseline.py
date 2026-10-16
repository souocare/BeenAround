"""Initial database baseline.

Revision ID: a88f2210d2e1
Revises:
"""

from collections.abc import Sequence

revision: str = "a88f2210d2e1"
down_revision: str | Sequence[str] | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Establish the initial migration baseline."""


def downgrade() -> None:
    """Remove the initial migration baseline."""
