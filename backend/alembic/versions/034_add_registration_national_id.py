"""Add National ID to borrower registration requests.

Revision ID: 034
Revises: 033
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "034"
down_revision: str | None = "033"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Nullable preserves pending requests submitted before this field existed.
    # The public schema requires it for every new request.
    op.add_column(
        "borrower_registration_requests",
        sa.Column("national_id", sa.String(100), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("borrower_registration_requests", "national_id")
