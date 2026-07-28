"""Associate new sync receipts with the authenticated actor.

Revision ID: 016
Revises: 015
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "016"
down_revision: str | None = "015"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Nullable preserves receipts written by earlier versions. All new writes
    # populate the actor and enforce ownership in application code.
    op.add_column(
        "sync_receipts",
        sa.Column("user_id", sa.String(length=36), nullable=True),
    )
    op.create_index("ix_sync_receipts_user_id", "sync_receipts", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_sync_receipts_user_id", table_name="sync_receipts")
    op.drop_column("sync_receipts", "user_id")
