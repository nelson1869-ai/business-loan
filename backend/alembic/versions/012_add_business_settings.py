"""Add persistent business presentation settings."""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "012_business_settings"
down_revision: str | None = "011_documents"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    table = op.create_table(
        "business_settings",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("business_name", sa.String(160), nullable=False),
        sa.Column("currency_code", sa.String(3), nullable=False),
        sa.Column("receipt_footer", sa.Text(), nullable=False),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.bulk_insert(
        table,
        [
            {
                "id": "default",
                "business_name": "Lending Nelson",
                "currency_code": "PHP",
                "receipt_footer": "",
            }
        ],
    )


def downgrade() -> None:
    op.drop_table("business_settings")
