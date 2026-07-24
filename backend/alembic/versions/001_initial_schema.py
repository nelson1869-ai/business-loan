"""Create users, borrowers, and audit_logs tables.

Revision ID: 001_initial_schema
Revises: None
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "001_initial_schema"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Create the initial production schema and indexes."""
    op.create_table(
        "users",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("username", sa.String(length=100), nullable=False),
        sa.Column("hashed_password", sa.String(length=255), nullable=False),
        sa.Column("role", sa.String(length=20), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.CheckConstraint("role IN ('officer', 'admin')", name="ck_users_role"),
    )
    op.create_index("ix_users_username", "users", ["username"], unique=True)

    op.create_table(
        "borrowers",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("first_name", sa.String(length=100), nullable=False),
        sa.Column("last_name", sa.String(length=100), nullable=False),
        sa.Column("national_id", sa.String(length=100), nullable=False),
        sa.Column("phone", sa.String(length=32), nullable=False),
        sa.Column("date_of_birth", sa.Date(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.CheckConstraint(
            "status IN ('Pending', 'Active', 'Synced', 'Defaulted', 'Deleted')",
            name="ck_borrowers_status",
        ),
    )
    op.create_index(
        "ix_borrowers_national_id", "borrowers", ["national_id"], unique=True
    )
    op.create_index("ix_borrowers_status", "borrowers", ["status"], unique=False)

    op.create_table(
        "audit_logs",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("action", sa.String(length=40), nullable=False),
        sa.Column("entity_name", sa.String(length=50), nullable=False),
        sa.Column("entity_id", sa.String(length=36), nullable=False),
        sa.Column(
            "timestamp",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("old_state_json", sa.Text(), nullable=True),
        sa.Column("new_state_json", sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="RESTRICT"),
    )
    op.create_index("ix_audit_logs_user_id", "audit_logs", ["user_id"], unique=False)
    op.create_index(
        "ix_audit_logs_entity_id", "audit_logs", ["entity_id"], unique=False
    )


def downgrade() -> None:
    """Drop the initial schema in reverse dependency order."""
    op.drop_index("ix_audit_logs_entity_id", table_name="audit_logs")
    op.drop_index("ix_audit_logs_user_id", table_name="audit_logs")
    op.drop_table("audit_logs")
    op.drop_index("ix_borrowers_status", table_name="borrowers")
    op.drop_index("ix_borrowers_national_id", table_name="borrowers")
    op.drop_table("borrowers")
    op.drop_index("ix_users_username", table_name="users")
    op.drop_table("users")
