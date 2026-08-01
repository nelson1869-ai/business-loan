"""Add automation_event_outbox table for durable n8n event dispatching.

Revision ID: 017
Revises: 016
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "017"
down_revision: str | None = "016"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "automation_event_outbox",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("event_id", sa.String(length=36), nullable=False),
        sa.Column("event_type", sa.String(length=100), nullable=False),
        sa.Column("event_version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column(
            "status",
            sa.String(length=30),
            nullable=False,
            server_default="pending",
        ),
        sa.Column(
            "attempt_count",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
        sa.Column("next_attempt_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_attempt_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("delivered_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_error", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.Column("correlation_id", sa.String(length=36), nullable=False),
        sa.Column("idempotency_key", sa.String(length=255), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("event_id"),
        sa.UniqueConstraint("idempotency_key"),
    )
    op.create_index(
        "ix_automation_event_outbox_event_id",
        "automation_event_outbox",
        ["event_id"],
    )
    op.create_index(
        "ix_automation_event_outbox_event_type",
        "automation_event_outbox",
        ["event_type"],
    )
    op.create_index(
        "ix_automation_event_outbox_status",
        "automation_event_outbox",
        ["status"],
    )
    op.create_index(
        "ix_automation_event_outbox_next_attempt_at",
        "automation_event_outbox",
        ["next_attempt_at"],
    )
    op.create_index(
        "ix_automation_event_outbox_created_at",
        "automation_event_outbox",
        ["created_at"],
    )
    op.create_index(
        "ix_automation_event_outbox_correlation_id",
        "automation_event_outbox",
        ["correlation_id"],
    )
    op.create_index(
        "ix_automation_event_outbox_idempotency_key",
        "automation_event_outbox",
        ["idempotency_key"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_automation_event_outbox_idempotency_key",
        table_name="automation_event_outbox",
    )
    op.drop_index(
        "ix_automation_event_outbox_correlation_id",
        table_name="automation_event_outbox",
    )
    op.drop_index(
        "ix_automation_event_outbox_created_at",
        table_name="automation_event_outbox",
    )
    op.drop_index(
        "ix_automation_event_outbox_next_attempt_at",
        table_name="automation_event_outbox",
    )
    op.drop_index(
        "ix_automation_event_outbox_status",
        table_name="automation_event_outbox",
    )
    op.drop_index(
        "ix_automation_event_outbox_event_type",
        table_name="automation_event_outbox",
    )
    op.drop_index(
        "ix_automation_event_outbox_event_id",
        table_name="automation_event_outbox",
    )
    op.drop_table("automation_event_outbox")
