"""Add append-only loan write-offs and recoveries.

Revision ID: 030
Revises: 029
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "030"
down_revision: str | None = "029"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.drop_constraint("ck_loans_status", "loans", type_="check")
    op.create_check_constraint(
        "ck_loans_status",
        "loans",
        "status IN ('Draft', 'Active', 'Paid', 'Overdue', 'Defaulted', "
        "'Cancelled', 'WrittenOff')",
    )
    op.create_table(
        "loan_write_offs",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "loan_id",
            sa.String(36),
            sa.ForeignKey("loans.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "approval_request_id",
            sa.String(36),
            sa.ForeignKey("approval_requests.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("amount", sa.Numeric(18, 2), nullable=False),
        sa.Column("effective_date", sa.Date(), nullable=False),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column(
            "written_off_by_user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint("loan_id", name="uq_loan_write_off_loan_id"),
        sa.UniqueConstraint(
            "approval_request_id", name="uq_write_off_approval_request"
        ),
        sa.CheckConstraint("amount > 0", name="ck_loan_write_off_amount_positive"),
    )
    op.create_index("ix_loan_write_offs_loan_id", "loan_write_offs", ["loan_id"])
    op.create_table(
        "write_off_recoveries",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("request_id", sa.String(36), nullable=False, unique=True),
        sa.Column(
            "write_off_id",
            sa.String(36),
            sa.ForeignKey("loan_write_offs.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("amount", sa.Numeric(18, 2), nullable=False),
        sa.Column("effective_date", sa.Date(), nullable=False),
        sa.Column("note", sa.Text()),
        sa.Column(
            "recorded_by_user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.CheckConstraint("amount > 0", name="ck_write_off_recovery_amount_positive"),
    )
    op.create_index(
        "ix_write_off_recoveries_write_off_id",
        "write_off_recoveries",
        ["write_off_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_write_off_recoveries_write_off_id", table_name="write_off_recoveries"
    )
    op.drop_table("write_off_recoveries")
    op.drop_index("ix_loan_write_offs_loan_id", table_name="loan_write_offs")
    op.drop_table("loan_write_offs")
    op.drop_constraint("ck_loans_status", "loans", type_="check")
    op.create_check_constraint(
        "ck_loans_status",
        "loans",
        "status IN ('Draft', 'Active', 'Paid', 'Overdue', 'Defaulted', 'Cancelled')",
    )
