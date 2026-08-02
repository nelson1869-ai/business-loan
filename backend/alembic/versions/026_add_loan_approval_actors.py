"""Record loan approval and disbursement actors.

Revision ID: 026
Revises: 025
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "026"
down_revision: str | None = "025"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("loans", sa.Column("approved_by_user_id", sa.String(36)))
    op.add_column("loans", sa.Column("disbursed_by_user_id", sa.String(36)))
    op.create_foreign_key(
        "fk_loans_approved_by_user",
        "loans",
        "users",
        ["approved_by_user_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        "fk_loans_disbursed_by_user",
        "loans",
        "users",
        ["disbursed_by_user_id"],
        ["id"],
        ondelete="RESTRICT",
    )


def downgrade() -> None:
    op.drop_constraint("fk_loans_disbursed_by_user", "loans", type_="foreignkey")
    op.drop_constraint("fk_loans_approved_by_user", "loans", type_="foreignkey")
    op.drop_column("loans", "disbursed_by_user_id")
    op.drop_column("loans", "approved_by_user_id")
