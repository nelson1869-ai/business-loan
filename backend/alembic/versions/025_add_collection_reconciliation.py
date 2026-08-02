"""Add cash collection sessions and payment reconciliation metadata.

Revision ID: 025
Revises: 024
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "025"
down_revision: str | None = "024"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "collection_sessions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "collector_user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "opened_by_user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("opening_cash", sa.Numeric(18, 2), nullable=False),
        sa.Column(
            "expected_cash", sa.Numeric(18, 2), nullable=False, server_default="0.00"
        ),
        sa.Column(
            "actual_cash", sa.Numeric(18, 2), nullable=False, server_default="0.00"
        ),
        sa.Column(
            "cash_variance", sa.Numeric(18, 2), nullable=False, server_default="0.00"
        ),
        sa.Column("variance_reason", sa.Text()),
        sa.Column(
            "deposit_amount", sa.Numeric(18, 2), nullable=False, server_default="0.00"
        ),
        sa.Column("deposit_reference", sa.String(120)),
        sa.Column("status", sa.String(20), nullable=False, server_default="open"),
        sa.Column(
            "reviewer_user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
        ),
        sa.Column("reviewed_at", sa.DateTime(timezone=True)),
        sa.Column("reconciled_at", sa.DateTime(timezone=True)),
        sa.Column("deposited_at", sa.DateTime(timezone=True)),
        sa.Column("closed_at", sa.DateTime(timezone=True)),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint(
            "deposit_reference", name="uq_collection_deposit_reference"
        ),
        sa.CheckConstraint(
            "status IN ('open', 'collecting', 'submitted', 'reviewed', "
            "'reconciled', 'deposited', 'closed')",
            name="ck_collection_session_status",
        ),
        sa.CheckConstraint(
            "opening_cash >= 0 AND expected_cash >= 0 AND actual_cash >= 0 "
            "AND deposit_amount >= 0",
            name="ck_collection_session_amounts_nonnegative",
        ),
    )
    op.create_index(
        "ix_collection_sessions_collector_user_id",
        "collection_sessions",
        ["collector_user_id"],
    )
    op.create_index(
        "uq_collection_session_collector_open",
        "collection_sessions",
        ["collector_user_id"],
        unique=True,
        postgresql_where=sa.text(
            "status IN ('open', 'collecting', 'submitted', 'reviewed', "
            "'reconciled', 'deposited')"
        ),
    )

    op.add_column(
        "payments",
        sa.Column(
            "payment_method",
            sa.String(20),
            nullable=False,
            server_default="unspecified",
        ),
    )
    op.add_column("payments", sa.Column("collection_session_id", sa.String(36)))
    op.add_column("payments", sa.Column("device_id", sa.String(120)))
    op.add_column("payments", sa.Column("receipt_number", sa.String(120)))
    op.add_column(
        "payments",
        sa.Column(
            "reconciliation_status",
            sa.String(20),
            nullable=False,
            server_default="unreconciled",
        ),
    )
    op.create_foreign_key(
        "fk_payments_collection_session",
        "payments",
        "collection_sessions",
        ["collection_session_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_unique_constraint(
        "uq_payments_receipt_number", "payments", ["receipt_number"]
    )
    op.create_check_constraint(
        "ck_payments_method",
        "payments",
        "payment_method IN ('unspecified', 'cash', 'bank', 'mobile_money')",
    )
    op.create_check_constraint(
        "ck_cash_payment_collection_session",
        "payments",
        "payment_method <> 'cash' OR collection_session_id IS NOT NULL",
    )
    op.create_check_constraint(
        "ck_payments_reconciliation_status",
        "payments",
        "reconciliation_status IN ('unreconciled', 'reconciled', 'reversed')",
    )


def downgrade() -> None:
    op.drop_constraint("ck_payments_reconciliation_status", "payments", type_="check")
    op.drop_constraint("ck_cash_payment_collection_session", "payments", type_="check")
    op.drop_constraint("ck_payments_method", "payments", type_="check")
    op.drop_constraint("uq_payments_receipt_number", "payments", type_="unique")
    op.drop_constraint("fk_payments_collection_session", "payments", type_="foreignkey")
    op.drop_column("payments", "reconciliation_status")
    op.drop_column("payments", "receipt_number")
    op.drop_column("payments", "device_id")
    op.drop_column("payments", "collection_session_id")
    op.drop_column("payments", "payment_method")
    op.drop_index(
        "uq_collection_session_collector_open", table_name="collection_sessions"
    )
    op.drop_index(
        "ix_collection_sessions_collector_user_id", table_name="collection_sessions"
    )
    op.drop_table("collection_sessions")
