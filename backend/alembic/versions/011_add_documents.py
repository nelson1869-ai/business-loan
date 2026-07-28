"""Add persistent borrower and loan documents."""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "011_documents"
down_revision: str | None = "010_notifications"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "documents",
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
            "uploaded_by_user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("title", sa.String(160), nullable=False),
        sa.Column("file_name", sa.String(255), nullable=False),
        sa.Column("content_type", sa.String(100), nullable=False),
        sa.Column("size_bytes", sa.Integer(), nullable=False),
        sa.Column("content", sa.LargeBinary(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("ix_documents_borrower_id", "documents", ["borrower_id"])
    op.create_index("ix_documents_loan_id", "documents", ["loan_id"])
    op.create_index(
        "ix_documents_uploaded_by_user_id", "documents", ["uploaded_by_user_id"]
    )


def downgrade() -> None:
    op.drop_index("ix_documents_uploaded_by_user_id", table_name="documents")
    op.drop_index("ix_documents_loan_id", table_name="documents")
    op.drop_index("ix_documents_borrower_id", table_name="documents")
    op.drop_table("documents")
