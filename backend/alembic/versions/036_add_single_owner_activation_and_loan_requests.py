"""Add single-owner activation codes and borrower loan requests.

Revision ID: 036
Revises: 035
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "036"
down_revision: str | None = "035"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 1. Add fields to borrower_accounts
    op.add_column("borrower_accounts", sa.Column("password_hash", sa.String(128), nullable=True))
    op.add_column("borrower_accounts", sa.Column("address", sa.Text(), nullable=True))
    op.add_column("borrower_accounts", sa.Column("id_photo_url", sa.Text(), nullable=True))
    op.add_column("borrower_accounts", sa.Column("selfie_url", sa.Text(), nullable=True))

    # 2. Add fields to borrower_registration_requests
    op.add_column("borrower_registration_requests", sa.Column("address", sa.Text(), nullable=True))
    op.add_column("borrower_registration_requests", sa.Column("id_photo_url", sa.Text(), nullable=True))
    op.add_column("borrower_registration_requests", sa.Column("selfie_url", sa.Text(), nullable=True))
    op.add_column("borrower_registration_requests", sa.Column("pin_hash", sa.String(128), nullable=True))
    op.drop_constraint("ck_registration_status", "borrower_registration_requests", type_="check")
    op.create_check_constraint(
        "ck_registration_status",
        "borrower_registration_requests",
        "status IN ('pending','approved','rejected','cancelled','expired','Pending','Approved','Rejected','Activated','Suspended','Disabled')"
    )

    # 3. Create borrower_activation_codes
    op.create_table(
        "borrower_activation_codes",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("borrower_id", sa.String(36), sa.ForeignKey("borrowers.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("borrower_account_id", sa.String(36), sa.ForeignKey("borrower_accounts.id", ondelete="CASCADE"), nullable=True, index=True),
        sa.Column("code_hash", sa.String(128), nullable=False, index=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False, index=True),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("max_attempts", sa.Integer(), nullable=False, server_default="5"),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_by_user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("activated_device_id", sa.String(120), nullable=True),
        sa.Column("activated_ip", sa.String(45), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )

    # 4. Create borrower_loan_requests
    op.create_table(
        "borrower_loan_requests",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("borrower_id", sa.String(36), sa.ForeignKey("borrowers.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("requested_amount", sa.Numeric(18, 2), nullable=False),
        sa.Column("requested_term_months", sa.Integer(), nullable=False),
        sa.Column("purpose", sa.Text(), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="submitted", index=True),
        sa.Column("owner_notes", sa.Text(), nullable=True),
        sa.Column("created_draft_loan_id", sa.String(36), sa.ForeignKey("loans.id", ondelete="SET NULL"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_table("borrower_loan_requests")
    op.drop_table("borrower_activation_codes")
    op.drop_column("borrower_registration_requests", "pin_hash")
    op.drop_column("borrower_registration_requests", "selfie_url")
    op.drop_column("borrower_registration_requests", "id_photo_url")
    op.drop_column("borrower_registration_requests", "address")
    op.drop_column("borrower_accounts", "selfie_url")
    op.drop_column("borrower_accounts", "id_photo_url")
    op.drop_column("borrower_accounts", "address")
    op.drop_column("borrower_accounts", "password_hash")
