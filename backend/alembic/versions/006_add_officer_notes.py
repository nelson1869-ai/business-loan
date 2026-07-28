"""Add persistent borrower and loan officer notes.

Revision ID: 006_officer_notes
Revises: 005_loan_lifecycle
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "006_officer_notes"
down_revision: str | None = "005_loan_lifecycle"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "notes",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "borrower_id",
            sa.String(36),
            sa.ForeignKey("borrowers.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "loan_id",
            sa.String(36),
            sa.ForeignKey("loans.id", ondelete="RESTRICT"),
            nullable=True,
        ),
        sa.Column(
            "author_user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("category", sa.String(40), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("ix_notes_borrower_id", "notes", ["borrower_id"])
    op.create_index("ix_notes_loan_id", "notes", ["loan_id"])
    op.create_index("ix_notes_author_user_id", "notes", ["author_user_id"])


def downgrade() -> None:
    op.drop_index("ix_notes_author_user_id", table_name="notes")
    op.drop_index("ix_notes_loan_id", table_name="notes")
    op.drop_index("ix_notes_borrower_id", table_name="notes")
    op.drop_table("notes")
