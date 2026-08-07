"""Add requested terms to borrower_loan_requests and repayment_structure to loans.

Revision ID: 042
Revises: 041
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "042"
down_revision: str | None = "041"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name='borrower_loan_requests' AND column_name='requested_payment_frequency'
            ) THEN
                ALTER TABLE borrower_loan_requests 
                ADD COLUMN requested_payment_frequency VARCHAR(20) NOT NULL DEFAULT 'monthly';
            END IF;

            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name='borrower_loan_requests' AND column_name='requested_repayment_structure'
            ) THEN
                ALTER TABLE borrower_loan_requests 
                ADD COLUMN requested_repayment_structure VARCHAR(30) NOT NULL DEFAULT 'principal_plus_interest';
            END IF;

            IF NOT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_name='loans' AND column_name='repayment_structure'
            ) THEN
                ALTER TABLE loans 
                ADD COLUMN repayment_structure VARCHAR(30) NOT NULL DEFAULT 'principal_plus_interest';
            END IF;
        END $$;
        """
    )


def downgrade() -> None:
    op.drop_column("loans", "repayment_structure")
    op.drop_column("borrower_loan_requests", "requested_repayment_structure")
    op.drop_column("borrower_loan_requests", "requested_payment_frequency")
