"""Add default_monthly_estimate_rate to business_settings.

Revision ID: 044
Revises: 043
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "044"
down_revision: str | None = "043"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "business_settings",
        sa.Column(
            "default_monthly_estimate_rate",
            sa.Numeric(10, 8),
            nullable=True,
        ),
    )
    op.execute(
        """
        DO 
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conname = 'ck_business_settings_estimate_rate'
            ) THEN
                ALTER TABLE business_settings
                ADD CONSTRAINT ck_business_settings_estimate_rate
                CHECK (default_monthly_estimate_rate >= 0);
            END IF;
        END ;
        """
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE business_settings "
        "DROP CONSTRAINT IF EXISTS ck_business_settings_estimate_rate;"
    )
    op.drop_column("business_settings", "default_monthly_estimate_rate")
