"""Add payment_receipts and borrower_notifications tables.

Revision ID: 037
Revises: 036
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "037"
down_revision: str | None = "036"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Create payment_receipts table
    op.create_table(
        "payment_receipts",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "payment_id",
            sa.String(36),
            sa.ForeignKey("payments.id", ondelete="RESTRICT"),
            nullable=False,
            unique=True,
        ),
        sa.Column("receipt_number", sa.String(120), nullable=False, unique=True),
        sa.Column("receipt_status", sa.String(30), nullable=False, server_default="Confirmed"),
        sa.Column(
            "borrower_id",
            sa.String(36),
            sa.ForeignKey("borrowers.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("borrower_name", sa.String(200), nullable=False),
        sa.Column("borrower_account_ref", sa.String(100), nullable=False),
        sa.Column(
            "loan_id",
            sa.String(36),
            sa.ForeignKey("loans.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("loan_reference", sa.String(100), nullable=False),
        sa.Column("payment_date", sa.Date(), nullable=False),
        sa.Column("payment_time", sa.DateTime(timezone=True), nullable=False),
        sa.Column("effective_date", sa.Date(), nullable=False),
        sa.Column("payment_method", sa.String(50), nullable=False),
        sa.Column("external_reference", sa.String(120), nullable=True),
        sa.Column("amount_received", sa.Numeric(18, 2), nullable=False),
        sa.Column("balance_before_payment", sa.Numeric(18, 2), nullable=False),
        sa.Column("principal_applied", sa.Numeric(18, 2), nullable=False),
        sa.Column("interest_applied", sa.Numeric(18, 2), nullable=False),
        sa.Column("penalty_applied", sa.Numeric(18, 2), nullable=False, server_default="0.00"),
        sa.Column("fees_applied", sa.Numeric(18, 2), nullable=False, server_default="0.00"),
        sa.Column("unapplied_credit", sa.Numeric(18, 2), nullable=False),
        sa.Column("remaining_principal", sa.Numeric(18, 2), nullable=False),
        sa.Column("outstanding_interest", sa.Numeric(18, 2), nullable=False, server_default="0.00"),
        sa.Column("overdue_amount", sa.Numeric(18, 2), nullable=False, server_default="0.00"),
        sa.Column("total_outstanding_amount", sa.Numeric(18, 2), nullable=False),
        sa.Column("next_payment_amount", sa.Numeric(18, 2), nullable=True),
        sa.Column("next_due_date", sa.Date(), nullable=True),
        sa.Column("loan_status_after", sa.String(30), nullable=False),
        sa.Column(
            "recorded_by_user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("recorded_by_name", sa.String(120), nullable=False),
        sa.Column("verification_token", sa.String(120), nullable=False, unique=True),
        sa.Column("receipt_version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column(
            "reversal_payment_id",
            sa.String(36),
            sa.ForeignKey("payments.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("reversal_reason", sa.Text(), nullable=True),
        sa.Column("reversal_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("deterministic_explanation", sa.Text(), nullable=False),
        sa.Column("ai_explanation", sa.Text(), nullable=True),
        sa.Column("ai_explanation_model", sa.String(50), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint(
            "receipt_status IN ('Confirmed', 'Reversed', 'PartiallyReversed', 'Voided')",
            name="ck_payment_receipts_status",
        ),
    )
    op.create_index("ix_payment_receipts_payment_id", "payment_receipts", ["payment_id"])
    op.create_index("ix_payment_receipts_receipt_number", "payment_receipts", ["receipt_number"])
    op.create_index("ix_payment_receipts_receipt_status", "payment_receipts", ["receipt_status"])
    op.create_index("ix_payment_receipts_borrower_id", "payment_receipts", ["borrower_id"])
    op.create_index("ix_payment_receipts_loan_id", "payment_receipts", ["loan_id"])
    op.create_index("ix_payment_receipts_verification_token", "payment_receipts", ["verification_token"])

    # Create borrower_notifications table
    op.create_table(
        "borrower_notifications",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "borrower_id",
            sa.String(36),
            sa.ForeignKey("borrowers.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("notification_type", sa.String(50), nullable=False, server_default="payment_receipt"),
        sa.Column("metadata_json", sa.Text(), nullable=True),
        sa.Column("is_read", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_borrower_notifications_borrower_id", "borrower_notifications", ["borrower_id"])
    op.create_index("ix_borrower_notifications_notification_type", "borrower_notifications", ["notification_type"])
    op.create_index("ix_borrower_notifications_is_read", "borrower_notifications", ["is_read"])
    op.create_index("ix_borrower_notifications_created_at", "borrower_notifications", ["created_at"])


def downgrade() -> None:
    op.drop_table("borrower_notifications")
    op.drop_table("payment_receipts")
