"""Add loan accounts and installment schedules.

Revision ID: 002_add_loans_and_installments
Revises: 001_initial_schema
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "002_add_loans_and_installments"
down_revision: str | None = "001_initial_schema"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create loan and installment tables with financial constraints."""
    op.create_table(
        "loans",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("borrower_id", sa.String(length=36), nullable=False),
        sa.Column("created_by_user_id", sa.String(length=36), nullable=False),
        sa.Column("original_principal", sa.Numeric(18, 2), nullable=False),
        sa.Column("outstanding_principal", sa.Numeric(18, 2), nullable=False),
        sa.Column("monthly_rate", sa.Numeric(10, 8), nullable=False),
        sa.Column("term_months", sa.SmallInteger(), nullable=False),
        sa.Column("payments_per_month", sa.SmallInteger(), nullable=False),
        sa.Column("number_of_payments", sa.Integer(), nullable=False),
        sa.Column("regular_payment_amount", sa.Numeric(18, 2), nullable=False),
        sa.Column("calculation_method", sa.String(length=40), nullable=False),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("first_due_date", sa.Date(), nullable=False),
        sa.Column("final_due_date", sa.Date(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.CheckConstraint(
            "calculation_method = 'fixed_periodic_reducing_balance'",
            name="ck_loans_calculation_method",
        ),
        sa.CheckConstraint(
            "number_of_payments > 0",
            name="ck_loans_number_of_payments",
        ),
        sa.CheckConstraint(
            "original_principal > 0",
            name="ck_loans_original_principal",
        ),
        sa.CheckConstraint(
            "outstanding_principal >= 0",
            name="ck_loans_outstanding_principal",
        ),
        sa.CheckConstraint(
            "monthly_rate >= 0",
            name="ck_loans_monthly_rate",
        ),
        sa.CheckConstraint(
            "payments_per_month > 0",
            name="ck_loans_payments_per_month",
        ),
        sa.CheckConstraint(
            "status IN ('Draft', 'Active', 'Paid', 'Overdue', 'Defaulted', 'Cancelled')",
            name="ck_loans_status",
        ),
        sa.CheckConstraint("term_months > 0", name="ck_loans_term_months"),
        sa.ForeignKeyConstraint(
            ["borrower_id"],
            ["borrowers.id"],
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["created_by_user_id"],
            ["users.id"],
            ondelete="RESTRICT",
        ),
    )
    op.create_index("ix_loans_borrower_id", "loans", ["borrower_id"])
    op.create_index("ix_loans_created_by_user_id", "loans", ["created_by_user_id"])
    op.create_index("ix_loans_status", "loans", ["status"])

    op.create_table(
        "installments",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("loan_id", sa.String(length=36), nullable=False),
        sa.Column("installment_number", sa.Integer(), nullable=False),
        sa.Column("due_date", sa.Date(), nullable=False),
        sa.Column("expected_payment", sa.Numeric(18, 2), nullable=False),
        sa.Column("expected_interest", sa.Numeric(18, 2), nullable=False),
        sa.Column("expected_principal", sa.Numeric(18, 2), nullable=False),
        sa.Column(
            "expected_remaining_principal",
            sa.Numeric(18, 2),
            nullable=False,
        ),
        sa.Column("paid_amount", sa.Numeric(18, 2), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.CheckConstraint(
            "installment_number > 0",
            name="ck_installments_number",
        ),
        sa.CheckConstraint(
            "expected_payment >= 0 AND expected_interest >= 0 "
            "AND expected_principal >= 0 AND expected_remaining_principal >= 0 "
            "AND paid_amount >= 0",
            name="ck_installments_non_negative_amounts",
        ),
        sa.CheckConstraint(
            "status IN ('Scheduled', 'PartiallyPaid', 'Paid', 'Overdue', 'Cancelled')",
            name="ck_installments_status",
        ),
        sa.ForeignKeyConstraint(
            ["loan_id"],
            ["loans.id"],
            ondelete="RESTRICT",
        ),
        sa.UniqueConstraint(
            "loan_id",
            "installment_number",
            name="uq_installments_loan_number",
        ),
    )
    op.create_index("ix_installments_due_date", "installments", ["due_date"])
    op.create_index("ix_installments_loan_id", "installments", ["loan_id"])
    op.create_index("ix_installments_status", "installments", ["status"])


def downgrade() -> None:
    """Drop installment and loan tables in dependency order."""
    op.drop_index("ix_installments_status", table_name="installments")
    op.drop_index("ix_installments_loan_id", table_name="installments")
    op.drop_index("ix_installments_due_date", table_name="installments")
    op.drop_table("installments")
    op.drop_index("ix_loans_status", table_name="loans")
    op.drop_index("ix_loans_created_by_user_id", table_name="loans")
    op.drop_index("ix_loans_borrower_id", table_name="loans")
    op.drop_table("loans")
