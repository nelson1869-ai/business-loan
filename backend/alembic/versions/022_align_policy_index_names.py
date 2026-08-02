"""Align loan policy index names with SQLAlchemy metadata.

Revision ID: 022
Revises: 021
"""

from collections.abc import Sequence

from alembic import op

revision: str = "022"
down_revision: str | None = "021"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute(
        "ALTER INDEX ix_policy_name RENAME TO ix_loan_policy_versions_policy_name"
    )
    op.execute("ALTER INDEX ix_policy_status RENAME TO ix_loan_policy_versions_status")
    op.execute(
        "ALTER INDEX ix_policy_effective_date "
        "RENAME TO ix_loan_policy_versions_effective_date"
    )


def downgrade() -> None:
    op.execute(
        "ALTER INDEX ix_loan_policy_versions_effective_date "
        "RENAME TO ix_policy_effective_date"
    )
    op.execute("ALTER INDEX ix_loan_policy_versions_status RENAME TO ix_policy_status")
    op.execute(
        "ALTER INDEX ix_loan_policy_versions_policy_name RENAME TO ix_policy_name"
    )
