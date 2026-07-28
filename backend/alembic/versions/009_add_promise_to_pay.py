"""Add structured promise-to-pay fields."""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "009_promise_to_pay"
down_revision: str | None = "008_followup_tasks"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "collection_task_states",
        sa.Column("promised_amount", sa.Numeric(18, 2), nullable=True),
    )
    op.add_column(
        "collection_task_states", sa.Column("promise_date", sa.Date(), nullable=True)
    )
    op.add_column(
        "collection_task_states",
        sa.Column("promise_status", sa.String(20), nullable=True),
    )
    op.add_column(
        "collection_task_states",
        sa.Column("linked_payment_id", sa.String(36), nullable=True),
    )
    op.create_foreign_key(
        "fk_collection_tasks_payment",
        "collection_task_states",
        "payments",
        ["linked_payment_id"],
        ["id"],
        ondelete="RESTRICT",
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_collection_tasks_payment", "collection_task_states", type_="foreignkey"
    )
    for column in (
        "linked_payment_id",
        "promise_status",
        "promise_date",
        "promised_amount",
    ):
        op.drop_column("collection_task_states", column)
