"""Remove obsolete borrower_otps table and normalize account/registration statuses to lower-case.

Revision ID: 039
Revises: 038
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "039"
down_revision: str | None = "038"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 1. Safely drop obsolete runtime OTP table
    op.execute("DROP TABLE IF EXISTS borrower_otps CASCADE")

    # 2. Normalize borrower_accounts account_status values to lower-case
    op.execute(
        """
        UPDATE borrower_accounts 
        SET account_status = CASE 
            WHEN LOWER(account_status) IN ('active', 'activated') THEN 'activated'
            WHEN LOWER(account_status) = 'approved' THEN 'approved'
            WHEN LOWER(account_status) = 'pending' THEN 'pending'
            WHEN LOWER(account_status) = 'suspended' THEN 'suspended'
            WHEN LOWER(account_status) = 'disabled' THEN 'disabled'
            ELSE LOWER(account_status)
        END
        """
    )

    # 3. Normalize borrower_registration_requests status values to lower-case
    op.execute(
        """
        UPDATE borrower_registration_requests 
        SET status = CASE 
            WHEN LOWER(status) = 'pending' THEN 'pending'
            WHEN LOWER(status) = 'approved' THEN 'approved'
            WHEN LOWER(status) = 'rejected' THEN 'rejected'
            WHEN LOWER(status) = 'cancelled' THEN 'cancelled'
            WHEN LOWER(status) = 'expired' THEN 'expired'
            ELSE LOWER(status)
        END
        """
    )


def downgrade() -> None:
    # Recreate borrower_otps table if rolling back
    op.create_table(
        "borrower_otps",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("phone_number_normalized", sa.String(32), nullable=False, index=True),
        sa.Column("otp_code_hash", sa.String(128), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False, index=True),
        sa.Column("attempts", sa.Integer, nullable=False, server_default="0"),
        sa.Column("resend_available_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
