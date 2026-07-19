"""Add immutable payments and allocation snapshots.

Revision ID: 004_add_payments_and_allocations
Revises: 003_add_loan_request_id
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "004_add_payments_and_allocations"
down_revision: str | None = "003_add_loan_request_id"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create payment ledger entries and exact allocation snapshots."""
    op.create_table(
        "payments",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("request_id", sa.String(length=36), nullable=False),
        sa.Column("loan_id", sa.String(length=36), nullable=False),
        sa.Column("installment_id", sa.String(length=36), nullable=True),
        sa.Column("recorded_by_user_id", sa.String(length=36), nullable=False),
        sa.Column("reversal_of_payment_id", sa.String(length=36), nullable=True),
        sa.Column("entry_type", sa.String(length=20), nullable=False),
        sa.Column("amount", sa.Numeric(18, 2), nullable=False),
        sa.Column("effective_date", sa.Date(), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.CheckConstraint("amount > 0", name="ck_payments_amount_positive"),
        sa.CheckConstraint(
            "entry_type IN ('Payment', 'Reversal')",
            name="ck_payments_entry_type",
        ),
        sa.CheckConstraint(
            "(entry_type = 'Payment' AND reversal_of_payment_id IS NULL) OR "
            "(entry_type = 'Reversal' AND reversal_of_payment_id IS NOT NULL)",
            name="ck_payments_reversal_link",
        ),
        sa.ForeignKeyConstraint(
            ["loan_id"],
            ["loans.id"],
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["installment_id"],
            ["installments.id"],
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["recorded_by_user_id"],
            ["users.id"],
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["reversal_of_payment_id"],
            ["payments.id"],
            ondelete="RESTRICT",
        ),
        sa.UniqueConstraint("request_id", name="uq_payments_request_id"),
        sa.UniqueConstraint(
            "reversal_of_payment_id",
            name="uq_payments_reversal_of_payment_id",
        ),
    )
    op.create_index("ix_payments_loan_id", "payments", ["loan_id"])
    op.create_index("ix_payments_installment_id", "payments", ["installment_id"])
    op.create_index(
        "ix_payments_recorded_by_user_id",
        "payments",
        ["recorded_by_user_id"],
    )
    op.create_index("ix_payments_entry_type", "payments", ["entry_type"])
    op.create_index("ix_payments_effective_date", "payments", ["effective_date"])

    op.create_table(
        "payment_allocations",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("payment_id", sa.String(length=36), nullable=False),
        sa.Column("interest_before", sa.Numeric(18, 2), nullable=False),
        sa.Column("principal_before", sa.Numeric(18, 2), nullable=False),
        sa.Column("applied_interest", sa.Numeric(18, 2), nullable=False),
        sa.Column("applied_principal", sa.Numeric(18, 2), nullable=False),
        sa.Column("unapplied_credit", sa.Numeric(18, 2), nullable=False),
        sa.Column("interest_after", sa.Numeric(18, 2), nullable=False),
        sa.Column("principal_after", sa.Numeric(18, 2), nullable=False),
        sa.Column("overdue_days", sa.Integer(), nullable=False),
        sa.Column("scheduled_period_days", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.CheckConstraint(
            "interest_before >= 0 AND principal_before >= 0 "
            "AND applied_interest >= 0 AND applied_principal >= 0 "
            "AND unapplied_credit >= 0 AND interest_after >= 0 "
            "AND principal_after >= 0",
            name="ck_payment_allocations_non_negative",
        ),
        sa.CheckConstraint(
            "overdue_days >= 0",
            name="ck_payment_allocations_overdue_days",
        ),
        sa.CheckConstraint(
            "scheduled_period_days > 0",
            name="ck_payment_allocations_period_days",
        ),
        sa.ForeignKeyConstraint(
            ["payment_id"],
            ["payments.id"],
            ondelete="RESTRICT",
        ),
        sa.UniqueConstraint(
            "payment_id",
            name="uq_payment_allocations_payment_id",
        ),
    )


def downgrade() -> None:
    """Drop payment allocation snapshots and ledger entries."""
    op.drop_table("payment_allocations")
    op.drop_index("ix_payments_effective_date", table_name="payments")
    op.drop_index("ix_payments_entry_type", table_name="payments")
    op.drop_index("ix_payments_recorded_by_user_id", table_name="payments")
    op.drop_index("ix_payments_installment_id", table_name="payments")
    op.drop_index("ix_payments_loan_id", table_name="payments")
    op.drop_table("payments")
