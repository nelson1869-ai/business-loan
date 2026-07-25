"""Add persistent collection task completion state."""

from collections.abc import Sequence
import sqlalchemy as sa
from alembic import op

revision: str = "007_collection_tasks"
down_revision: str | None = "006_officer_notes"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "collection_task_states",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("loan_id", sa.String(36), sa.ForeignKey("loans.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("installment_number", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("completed_by_user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("loan_id", "installment_number", name="uq_collection_task_installment"),
    )
    op.create_index("ix_collection_task_states_loan_id", "collection_task_states", ["loan_id"])


def downgrade() -> None:
    op.drop_index("ix_collection_task_states_loan_id", table_name="collection_task_states")
    op.drop_table("collection_task_states")
