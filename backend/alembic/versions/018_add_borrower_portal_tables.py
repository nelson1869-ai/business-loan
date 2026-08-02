"""Add borrower portal tables (borrower_accounts, invitations, otps, refresh_tokens, devices).

Revision ID: 018
Revises: 017
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "018"
down_revision: str | None = "017"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 1. borrower_accounts
    op.create_table(
        "borrower_accounts",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("borrower_id", sa.String(length=36), nullable=False),
        sa.Column("phone_number", sa.String(length=32), nullable=False),
        sa.Column("phone_number_normalized", sa.String(length=32), nullable=False),
        sa.Column("phone_verified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "account_status",
            sa.String(length=20),
            server_default="pending",
            nullable=False,
        ),
        sa.Column(
            "failed_login_attempts", sa.Integer(), server_default="0", nullable=False
        ),
        sa.Column("locked_until", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_login_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["borrower_id"], ["borrowers.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_borrower_accounts_borrower_id",
        "borrower_accounts",
        ["borrower_id"],
        unique=True,
    )
    op.create_index(
        "ix_borrower_accounts_phone_number_normalized",
        "borrower_accounts",
        ["phone_number_normalized"],
        unique=True,
    )
    op.create_index(
        "ix_borrower_accounts_account_status", "borrower_accounts", ["account_status"]
    )

    # 2. borrower_invitations
    op.create_table(
        "borrower_invitations",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("borrower_id", sa.String(length=36), nullable=False),
        sa.Column("invitation_code_hash", sa.String(length=128), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_by_user_id", sa.String(length=36), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["borrower_id"], ["borrowers.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["created_by_user_id"], ["users.id"], ondelete="RESTRICT"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_borrower_invitations_borrower_id", "borrower_invitations", ["borrower_id"]
    )
    op.create_index(
        "ix_borrower_invitations_expires_at", "borrower_invitations", ["expires_at"]
    )

    # 3. borrower_otps
    op.create_table(
        "borrower_otps",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("phone_number_normalized", sa.String(length=32), nullable=False),
        sa.Column("otp_code_hash", sa.String(length=128), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("attempts", sa.Integer(), server_default="0", nullable=False),
        sa.Column("resend_available_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_borrower_otps_phone_number_normalized",
        "borrower_otps",
        ["phone_number_normalized"],
    )
    op.create_index("ix_borrower_otps_expires_at", "borrower_otps", ["expires_at"])

    # 4. borrower_refresh_tokens
    op.create_table(
        "borrower_refresh_tokens",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("borrower_account_id", sa.String(length=36), nullable=False),
        sa.Column("token_hash", sa.String(length=128), nullable=False),
        sa.Column("device_id", sa.String(length=36), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["borrower_account_id"], ["borrower_accounts.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_borrower_refresh_tokens_borrower_account_id",
        "borrower_refresh_tokens",
        ["borrower_account_id"],
    )
    op.create_index(
        "ix_borrower_refresh_tokens_token_hash",
        "borrower_refresh_tokens",
        ["token_hash"],
        unique=True,
    )
    op.create_index(
        "ix_borrower_refresh_tokens_expires_at",
        "borrower_refresh_tokens",
        ["expires_at"],
    )

    # 5. borrower_devices
    op.create_table(
        "borrower_devices",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("borrower_account_id", sa.String(length=36), nullable=False),
        sa.Column("device_identifier_hash", sa.String(length=128), nullable=False),
        sa.Column("platform", sa.String(length=20), nullable=False),
        sa.Column("push_token", sa.String(length=512), nullable=True),
        sa.Column("push_token_updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "last_seen_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["borrower_account_id"], ["borrower_accounts.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_borrower_devices_borrower_account_id",
        "borrower_devices",
        ["borrower_account_id"],
    )
    op.create_index(
        "ix_borrower_devices_device_identifier_hash",
        "borrower_devices",
        ["device_identifier_hash"],
    )


def downgrade() -> None:
    op.drop_table("borrower_devices")
    op.drop_table("borrower_refresh_tokens")
    op.drop_table("borrower_otps")
    op.drop_table("borrower_invitations")
    op.drop_table("borrower_accounts")
