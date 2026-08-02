"""Add versioned loan policies and immutable loan policy snapshots.

Revision ID: 021
Revises: 020
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "021"
down_revision: str | None = "020"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "loan_policy_versions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("policy_name", sa.String(160), nullable=False),
        sa.Column("version_number", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(16), nullable=False, server_default="draft"),
        sa.Column("currency", sa.String(3), nullable=False),
        sa.Column("interest_method", sa.String(64), nullable=False),
        sa.Column("rate_period", sa.String(32), nullable=False),
        sa.Column("minimum_rate", sa.Numeric(10, 8), nullable=False),
        sa.Column("maximum_rate", sa.Numeric(10, 8), nullable=False),
        sa.Column("rounding_policy", sa.JSON(), nullable=False),
        sa.Column("payment_allocation_order", sa.JSON(), nullable=False),
        sa.Column("grace_period_configuration", sa.JSON(), nullable=False),
        sa.Column("late_fee_configuration", sa.JSON(), nullable=False),
        sa.Column("early_settlement_configuration", sa.JSON(), nullable=False),
        sa.Column("excess_payment_treatment", sa.JSON(), nullable=False),
        sa.Column("restructuring_policy", sa.JSON(), nullable=False),
        sa.Column("write_off_policy", sa.JSON(), nullable=False),
        sa.Column("contract_template_version", sa.String(64), nullable=False),
        sa.Column("effective_date", sa.Date(), nullable=False),
        sa.Column("change_reason", sa.Text(), nullable=False),
        sa.Column(
            "created_by_user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "approved_by_user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
        ),
        sa.Column("approved_at", sa.DateTime(timezone=True)),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint(
            "policy_name", "version_number", name="uq_policy_name_version"
        ),
        sa.CheckConstraint(
            "status IN ('draft', 'active', 'retired')", name="ck_policy_status"
        ),
        sa.CheckConstraint(
            "minimum_rate >= 0 AND maximum_rate >= minimum_rate",
            name="ck_policy_rate_range",
        ),
        sa.CheckConstraint("currency ~ '^[A-Z]{3}$'", name="ck_policy_currency"),
    )
    op.create_index("ix_policy_name", "loan_policy_versions", ["policy_name"])
    op.create_index("ix_policy_status", "loan_policy_versions", ["status"])
    op.create_index(
        "ix_policy_effective_date", "loan_policy_versions", ["effective_date"]
    )
    op.add_column("loans", sa.Column("policy_version_id", sa.String(36), nullable=True))
    op.add_column("loans", sa.Column("policy_snapshot", sa.JSON(), nullable=True))
    op.execute("""
        UPDATE loans SET policy_snapshot = json_build_object(
          'source', 'legacy-explicit-terms',
          'calculationMethod', calculation_method,
          'monthlyRate', monthly_rate::text,
          'rounding', 'ROUND_HALF_UP',
          'paymentAllocationOrder', json_build_array('interest', 'principal', 'unapplied_credit')
        )
    """)
    op.alter_column("loans", "policy_snapshot", nullable=False)
    op.create_foreign_key(
        "fk_loans_policy_version",
        "loans",
        "loan_policy_versions",
        ["policy_version_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_index("ix_loans_policy_version_id", "loans", ["policy_version_id"])


def downgrade() -> None:
    op.drop_index("ix_loans_policy_version_id", table_name="loans")
    op.drop_constraint("fk_loans_policy_version", "loans", type_="foreignkey")
    op.drop_column("loans", "policy_snapshot")
    op.drop_column("loans", "policy_version_id")
    op.drop_table("loan_policy_versions")
