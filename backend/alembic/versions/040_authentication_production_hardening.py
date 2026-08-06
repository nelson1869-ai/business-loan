"""Remove legacy borrower_invitations table and add is_trusted column to borrower_devices.

Revision ID: 040
Revises: 039
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "040"
down_revision: str | None = "039"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 1. Drop obsolete borrower_invitations table
    op.execute("DROP TABLE IF EXISTS borrower_invitations CASCADE")

    # 2. Add is_trusted column to borrower_devices if it does not already exist
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name='borrower_devices' AND column_name='is_trusted'
            ) THEN
                ALTER TABLE borrower_devices ADD COLUMN is_trusted BOOLEAN NOT NULL DEFAULT false;
            END IF;
        END $$;
        """
    )

    # 3. Normalize any unexpected status values to canonical lower-case
    op.execute(
        """
        UPDATE borrower_accounts 
        SET account_status = CASE 
            WHEN LOWER(account_status) IN ('active', 'activated') THEN 'activated'
            WHEN LOWER(account_status) = 'approved' THEN 'approved'
            WHEN LOWER(account_status) = 'pending' THEN 'pending'
            WHEN LOWER(account_status) = 'suspended' THEN 'suspended'
            WHEN LOWER(account_status) = 'disabled' THEN 'disabled'
            ELSE 'disabled'
        END
        WHERE account_status NOT IN ('pending', 'approved', 'activated', 'suspended', 'disabled')
        """
    )
    op.execute("ALTER TABLE borrower_accounts DROP CONSTRAINT IF EXISTS ck_borrower_accounts_status")
    op.execute(
        """
        ALTER TABLE borrower_accounts
        ADD CONSTRAINT ck_borrower_accounts_status
        CHECK (account_status IN ('pending', 'approved', 'activated', 'suspended', 'disabled'))
        """
    )


def downgrade() -> None:
    op.execute("ALTER TABLE borrower_accounts DROP CONSTRAINT IF EXISTS ck_borrower_accounts_status")
    op.drop_column("borrower_devices", "is_trusted")
    op.create_table(
        "borrower_invitations",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("borrower_id", sa.String(36), nullable=False, index=True),
        sa.Column("invitation_code_hash", sa.String(128), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False, index=True),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_by_user_id", sa.String(36), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
