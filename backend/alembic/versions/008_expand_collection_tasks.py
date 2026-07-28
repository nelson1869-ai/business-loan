"""Expand collection tasks into schedulable follow-ups."""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "008_followup_tasks"
down_revision: str | None = "007_collection_tasks"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "collection_task_states", sa.Column("borrower_id", sa.String(36), nullable=True)
    )
    op.add_column(
        "collection_task_states", sa.Column("task_type", sa.String(30), nullable=True)
    )
    op.add_column(
        "collection_task_states", sa.Column("priority", sa.String(20), nullable=True)
    )
    op.add_column(
        "collection_task_states", sa.Column("description", sa.Text(), nullable=True)
    )
    op.add_column(
        "collection_task_states",
        sa.Column("due_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "collection_task_states",
        sa.Column("created_by_user_id", sa.String(36), nullable=True),
    )
    op.add_column(
        "collection_task_states",
        sa.Column("assigned_to_user_id", sa.String(36), nullable=True),
    )
    op.add_column(
        "collection_task_states", sa.Column("completion_note", sa.Text(), nullable=True)
    )
    op.add_column(
        "collection_task_states",
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.execute(
        """
        UPDATE collection_task_states AS task
        SET borrower_id = loan.borrower_id,
            task_type = 'Visit',
            priority = 'Normal',
            due_at = task.completed_at,
            created_by_user_id = task.completed_by_user_id,
            assigned_to_user_id = task.completed_by_user_id
        FROM loans AS loan
        WHERE loan.id = task.loan_id
        """
    )
    for column in (
        "borrower_id",
        "task_type",
        "priority",
        "due_at",
        "created_by_user_id",
        "assigned_to_user_id",
    ):
        op.alter_column("collection_task_states", column, nullable=False)
    op.alter_column("collection_task_states", "installment_number", nullable=True)
    op.alter_column("collection_task_states", "completed_by_user_id", nullable=True)
    op.alter_column("collection_task_states", "completed_at", nullable=True)
    op.create_foreign_key(
        "fk_collection_tasks_borrower",
        "collection_task_states",
        "borrowers",
        ["borrower_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        "fk_collection_tasks_created_by",
        "collection_task_states",
        "users",
        ["created_by_user_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        "fk_collection_tasks_assigned_to",
        "collection_task_states",
        "users",
        ["assigned_to_user_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_index(
        "ix_collection_task_states_borrower_id",
        "collection_task_states",
        ["borrower_id"],
    )
    op.create_index(
        "ix_collection_task_states_assigned_to_user_id",
        "collection_task_states",
        ["assigned_to_user_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_collection_task_states_assigned_to_user_id",
        table_name="collection_task_states",
    )
    op.drop_index(
        "ix_collection_task_states_borrower_id", table_name="collection_task_states"
    )
    op.drop_constraint(
        "fk_collection_tasks_assigned_to", "collection_task_states", type_="foreignkey"
    )
    op.drop_constraint(
        "fk_collection_tasks_created_by", "collection_task_states", type_="foreignkey"
    )
    op.drop_constraint(
        "fk_collection_tasks_borrower", "collection_task_states", type_="foreignkey"
    )
    op.alter_column("collection_task_states", "completed_at", nullable=False)
    op.alter_column("collection_task_states", "completed_by_user_id", nullable=False)
    op.alter_column("collection_task_states", "installment_number", nullable=False)
    for column in (
        "created_at",
        "completion_note",
        "assigned_to_user_id",
        "created_by_user_id",
        "due_at",
        "description",
        "priority",
        "task_type",
        "borrower_id",
    ):
        op.drop_column("collection_task_states", column)
