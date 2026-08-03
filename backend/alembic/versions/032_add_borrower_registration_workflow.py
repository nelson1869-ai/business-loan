"""Add borrower self-registration review workflow.

Revision ID: 032
Revises: 031
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "032"
down_revision: str | None = "031"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "borrower_registration_requests",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("first_name", sa.String(100), nullable=False),
        sa.Column("middle_name", sa.String(100)),
        sa.Column("last_name", sa.String(100), nullable=False),
        sa.Column("suffix", sa.String(30)),
        sa.Column("phone_number", sa.String(32), nullable=False),
        sa.Column("phone_number_normalized", sa.String(32), nullable=False),
        sa.Column("date_of_birth", sa.Date(), nullable=False),
        sa.Column("email", sa.String(254)),
        sa.Column("status", sa.String(20), server_default="pending", nullable=False),
        sa.Column("status_token_hash", sa.String(128), nullable=False),
        sa.Column("privacy_accepted_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("terms_accepted_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "submitted_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("reviewed_at", sa.DateTime(timezone=True)),
        sa.Column(
            "reviewed_by_user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
        ),
        sa.Column("review_notes", sa.Text()),
        sa.Column("rejection_reason", sa.String(500)),
        sa.Column(
            "linked_borrower_id",
            sa.String(36),
            sa.ForeignKey("borrowers.id", ondelete="RESTRICT"),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "status IN ('pending','approved','rejected','cancelled','expired')",
            name="ck_registration_status",
        ),
    )
    op.create_index(
        "ix_registration_status", "borrower_registration_requests", ["status"]
    )
    op.create_index(
        "ix_registration_phone",
        "borrower_registration_requests",
        ["phone_number_normalized"],
    )
    op.create_index(
        "ix_registration_token_hash",
        "borrower_registration_requests",
        ["status_token_hash"],
        unique=True,
    )
    op.create_index(
        "ix_registration_linked_borrower",
        "borrower_registration_requests",
        ["linked_borrower_id"],
    )
    op.create_index(
        "ix_registration_pending_phone",
        "borrower_registration_requests",
        ["phone_number_normalized", "status"],
    )
    op.create_table(
        "borrower_registration_audits",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "actor_user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
        ),
        sa.Column("action", sa.String(50), nullable=False),
        sa.Column("target_type", sa.String(40), nullable=False),
        sa.Column("target_id", sa.String(36), nullable=False),
        sa.Column("metadata_json", sa.Text()),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
    )
    op.create_index(
        "ix_registration_audit_actor", "borrower_registration_audits", ["actor_user_id"]
    )
    op.create_index(
        "ix_registration_audit_action", "borrower_registration_audits", ["action"]
    )
    op.create_index(
        "ix_registration_audit_target", "borrower_registration_audits", ["target_id"]
    )


def downgrade() -> None:
    op.drop_table("borrower_registration_audits")
    op.drop_table("borrower_registration_requests")
