"""Bind payment reversals to one consumed approval request.

Revision ID: 028
Revises: 027
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "028"
down_revision: str | None = "027"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("payments", sa.Column("approval_request_id", sa.String(36)))
    op.create_foreign_key(
        "fk_payments_approval_request",
        "payments",
        "approval_requests",
        ["approval_request_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_unique_constraint(
        "uq_payments_approval_request_id", "payments", ["approval_request_id"]
    )


def downgrade() -> None:
    op.drop_constraint("uq_payments_approval_request_id", "payments", type_="unique")
    op.drop_constraint("fk_payments_approval_request", "payments", type_="foreignkey")
    op.drop_column("payments", "approval_request_id")
