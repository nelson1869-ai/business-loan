"""Production hardening of borrower authentication, device security, and PIN reset.

Revision ID: 038
Revises: 037
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "038"
down_revision: str | None = "037"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 1. Add login timestamp fields to borrower_accounts
    op.add_column(
        "borrower_accounts",
        sa.Column("last_failed_login", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "borrower_accounts",
        sa.Column("last_successful_login", sa.DateTime(timezone=True), nullable=True),
    )

    # 2. Add metadata & trust columns to borrower_devices
    op.add_column(
        "borrower_devices",
        sa.Column("device_name", sa.String(100), nullable=True),
    )
    op.add_column(
        "borrower_devices",
        sa.Column("model", sa.String(100), nullable=True),
    )
    op.add_column(
        "borrower_devices",
        sa.Column("app_version", sa.String(50), nullable=True),
    )
    op.add_column(
        "borrower_devices",
        sa.Column(
            "first_seen_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
    )
    op.add_column(
        "borrower_devices",
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "borrower_devices",
        sa.Column(
            "is_trusted",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("true"),
        ),
    )

    # 3. Create borrower_pin_resets table
    op.create_table(
        "borrower_pin_resets",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "borrower_account_id",
            sa.String(36),
            sa.ForeignKey("borrower_accounts.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("code_hash", sa.String(128), nullable=False, index=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False, index=True),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("max_attempts", sa.Integer(), nullable=False, server_default="5"),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_by_user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
    )


def downgrade() -> None:
    op.drop_table("borrower_pin_resets")
    op.drop_column("borrower_devices", "is_trusted")
    op.drop_column("borrower_devices", "revoked_at")
    op.drop_column("borrower_devices", "first_seen_at")
    op.drop_column("borrower_devices", "app_version")
    op.drop_column("borrower_devices", "model")
    op.drop_column("borrower_devices", "device_name")
    op.drop_column("borrower_accounts", "last_successful_login")
    op.drop_column("borrower_accounts", "last_failed_login")
