"""Add borrower portal device composite indexes.

Revision ID: 019
Revises: 018
Create Date: 2026-08-02
"""

from typing import Sequence, Union

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "019"
down_revision: Union[str, None] = "018"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_index(
        "ix_borrower_devices_account_device_hash",
        "borrower_devices",
        ["borrower_account_id", "device_identifier_hash"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_borrower_devices_account_device_hash",
        table_name="borrower_devices",
    )
