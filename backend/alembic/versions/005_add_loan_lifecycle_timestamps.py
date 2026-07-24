"""Add non-breaking loan lifecycle timestamps.

Revision ID: 005_loan_lifecycle
Revises: 004_add_payments_and_allocations
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "005_loan_lifecycle"
down_revision: str | None = "004_add_payments_and_allocations"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    for name in (
        "approved_at",
        "disbursed_at",
        "activated_at",
        "completed_at",
        "defaulted_at",
        "cancelled_at",
        "closed_at",
    ):
        op.add_column(
            "loans", sa.Column(name, sa.DateTime(timezone=True), nullable=True)
        )


def downgrade() -> None:
    for name in reversed(
        (
            "approved_at",
            "disbursed_at",
            "activated_at",
            "completed_at",
            "defaulted_at",
            "cancelled_at",
            "closed_at",
        )
    ):
        op.drop_column("loans", name)
