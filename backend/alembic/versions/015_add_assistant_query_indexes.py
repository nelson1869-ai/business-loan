"""Add composite indexes used by read-only assistant queries.

Revision ID: 015
Revises: 014
"""

from collections.abc import Sequence

from alembic import op

revision: str = "015"
down_revision: str | None = "014"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_index(
        "ix_loans_borrower_status",
        "loans",
        ["borrower_id", "status"],
    )
    op.create_index(
        "ix_installments_status_due_date",
        "installments",
        ["status", "due_date"],
    )
    op.create_index(
        "ix_payments_loan_effective_date",
        "payments",
        ["loan_id", "effective_date"],
    )


def downgrade() -> None:
    op.drop_index("ix_payments_loan_effective_date", table_name="payments")
    op.drop_index("ix_installments_status_due_date", table_name="installments")
    op.drop_index("ix_loans_borrower_status", table_name="loans")
