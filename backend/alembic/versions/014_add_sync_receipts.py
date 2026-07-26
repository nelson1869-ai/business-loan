"""Add durable offline synchronization receipts.

Revision ID: 014
Revises: 013
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "014"
down_revision: str | None = "013"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "sync_receipts",
        sa.Column("transaction_uuid", sa.String(length=36), nullable=False),
        sa.Column("applied_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("transaction_uuid"),
    )


def downgrade() -> None:
    op.drop_table("sync_receipts")
