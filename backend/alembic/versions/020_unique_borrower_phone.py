"""Enforce one normalized phone number per borrower.

Revision ID: 020
Revises: 019
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "020"
down_revision: str | None = "019"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    """Backfill canonical phones and enforce database uniqueness."""
    op.add_column(
        "borrowers",
        sa.Column("phone_normalized", sa.String(length=13), nullable=True),
    )
    op.execute(
        """
        UPDATE borrowers
        SET phone_normalized = CASE
            WHEN regexp_replace(phone, '[^0-9]', '', 'g') ~ '^09[0-9]{9}$'
                THEN '+63' || substring(regexp_replace(phone, '[^0-9]', '', 'g') FROM 2)
            WHEN regexp_replace(phone, '[^0-9]', '', 'g') ~ '^639[0-9]{9}$'
                THEN '+' || regexp_replace(phone, '[^0-9]', '', 'g')
            WHEN regexp_replace(phone, '[^0-9]', '', 'g') ~ '^9[0-9]{9}$'
                THEN '+63' || regexp_replace(phone, '[^0-9]', '', 'g')
            WHEN regexp_replace(phone, '[^0-9]', '', 'g') ~ '^6309[0-9]{9}$'
                THEN '+63' || substring(regexp_replace(phone, '[^0-9]', '', 'g') FROM 4)
            ELSE NULL
        END
        """
    )
    op.alter_column("borrowers", "phone_normalized", nullable=False)
    op.create_index(
        "ix_borrowers_phone_normalized",
        "borrowers",
        ["phone_normalized"],
        unique=False,
    )
    op.create_unique_constraint(
        "uq_borrowers_phone_normalized",
        "borrowers",
        ["phone_normalized"],
    )


def downgrade() -> None:
    """Remove normalized borrower phone enforcement."""
    op.drop_constraint(
        "uq_borrowers_phone_normalized",
        "borrowers",
        type_="unique",
    )
    op.drop_index("ix_borrowers_phone_normalized", table_name="borrowers")
    op.drop_column("borrowers", "phone_normalized")
