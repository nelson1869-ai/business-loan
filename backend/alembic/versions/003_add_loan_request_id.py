"""Add the unique loan idempotency request identifier.

Revision ID: 003_add_loan_request_id
Revises: 002_add_loans_and_installments
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "003_add_loan_request_id"
down_revision: str | None = "002_add_loans_and_installments"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Add and backfill a required unique request ID without deleting loans."""
    op.add_column(
        "loans",
        sa.Column("request_id", sa.String(length=36), nullable=True),
    )
    op.execute("UPDATE loans SET request_id = id WHERE request_id IS NULL")
    op.alter_column("loans", "request_id", nullable=False)
    op.create_unique_constraint(
        "uq_loans_request_id",
        "loans",
        ["request_id"],
    )


def downgrade() -> None:
    """Remove the idempotency request identifier."""
    op.drop_constraint("uq_loans_request_id", "loans", type_="unique")
    op.drop_column("loans", "request_id")
