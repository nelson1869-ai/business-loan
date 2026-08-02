"""Add reusable maker-checker approval requests.

Revision ID: 027
Revises: 026
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "027"
down_revision: str | None = "026"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "approval_requests",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("action", sa.String(64), nullable=False),
        sa.Column("entity_type", sa.String(64), nullable=False),
        sa.Column("entity_id", sa.String(64), nullable=False),
        sa.Column(
            "maker_user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "checker_user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
        ),
        sa.Column("status", sa.String(16), nullable=False, server_default="pending"),
        sa.Column("decision", sa.String(16)),
        sa.Column("request_reason", sa.Text(), nullable=False),
        sa.Column("decision_reason", sa.Text()),
        sa.Column("before_state_json", sa.Text()),
        sa.Column("after_state_json", sa.Text()),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("decided_at", sa.DateTime(timezone=True)),
        sa.Column("consumed_at", sa.DateTime(timezone=True)),
        sa.CheckConstraint(
            "status IN ('pending', 'approved', 'rejected', 'cancelled', 'consumed')",
            name="ck_approval_request_status",
        ),
        sa.CheckConstraint(
            "decision IN ('approved', 'rejected') OR decision IS NULL",
            name="ck_approval_request_decision",
        ),
        sa.CheckConstraint(
            "checker_user_id IS NULL OR checker_user_id <> maker_user_id",
            name="ck_approval_distinct_checker",
        ),
    )
    op.create_index(
        "ix_approval_requests_maker_user_id",
        "approval_requests",
        ["maker_user_id"],
    )
    op.create_index(
        "ix_approval_requests_checker_user_id",
        "approval_requests",
        ["checker_user_id"],
    )
    op.create_index(
        "uq_approval_pending_action_entity",
        "approval_requests",
        ["action", "entity_type", "entity_id"],
        unique=True,
        postgresql_where=sa.text("status = 'pending'"),
    )


def downgrade() -> None:
    op.drop_index("uq_approval_pending_action_entity", table_name="approval_requests")
    op.drop_index(
        "ix_approval_requests_checker_user_id", table_name="approval_requests"
    )
    op.drop_index("ix_approval_requests_maker_user_id", table_name="approval_requests")
    op.drop_table("approval_requests")
