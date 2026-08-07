"""Add deduplication_key column to borrower_notifications table.

Revision ID: 041
Revises: 040
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "041"
down_revision: str | None = "040"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name='borrower_notifications' AND column_name='deduplication_key'
            ) THEN
                ALTER TABLE borrower_notifications ADD COLUMN deduplication_key VARCHAR(120);
                CREATE UNIQUE INDEX ix_borrower_notifications_deduplication_key 
                ON borrower_notifications (deduplication_key);
            END IF;
        END $$;
        """
    )


def downgrade() -> None:
    op.drop_index("ix_borrower_notifications_deduplication_key", table_name="borrower_notifications")
    op.drop_column("borrower_notifications", "deduplication_key")
