"""Add CHECK constraints to borrower_loan_requests and loans tables.

Revision ID: 043
Revises: 042
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "043"
down_revision: str | None = "042"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint 
                WHERE conname = 'ck_borrower_loan_requests_requested_payment_frequency'
            ) THEN
                ALTER TABLE borrower_loan_requests 
                ADD CONSTRAINT ck_borrower_loan_requests_requested_payment_frequency 
                CHECK (requested_payment_frequency IN ('monthly', 'twice_a_month'));
            END IF;

            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint 
                WHERE conname = 'ck_borrower_loan_requests_requested_repayment_structure'
            ) THEN
                ALTER TABLE borrower_loan_requests 
                ADD CONSTRAINT ck_borrower_loan_requests_requested_repayment_structure 
                CHECK (requested_repayment_structure IN ('principal_plus_interest', 'interest_only'));
            END IF;

            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint 
                WHERE conname = 'ck_loans_repayment_structure'
            ) THEN
                ALTER TABLE loans 
                ADD CONSTRAINT ck_loans_repayment_structure 
                CHECK (repayment_structure IN ('principal_plus_interest', 'interest_only'));
            END IF;
        END $$;
        """
    )


def downgrade() -> None:
    op.execute(
        """
        ALTER TABLE borrower_loan_requests DROP CONSTRAINT IF EXISTS ck_borrower_loan_requests_requested_payment_frequency;
        ALTER TABLE borrower_loan_requests DROP CONSTRAINT IF EXISTS ck_borrower_loan_requests_requested_repayment_structure;
        ALTER TABLE loans DROP CONSTRAINT IF EXISTS ck_loans_repayment_structure;
        """
    )
