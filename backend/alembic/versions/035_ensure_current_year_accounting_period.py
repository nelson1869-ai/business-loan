"""Ensure an open accounting period exists for the current calendar year.

This is a remediation migration for single-owner deployments where the
initial seed (migration 024) created a period for the deployment year only.
When the server rolls into a new year with no open period, all disbursements
and journal postings fail with 'No open accounting period covers the posting date'.

This migration is idempotent — it will not overwrite an existing period.

Revision ID: 035
Revises: 034
"""

from collections.abc import Sequence
from uuid import uuid4

from alembic import op

revision: str = "035"
down_revision: str | None = "034"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Insert an open period for the current calendar year.
    # ON CONFLICT (start_date, end_date) DO NOTHING makes this safe to
    # re-run or run when the year already has a period.
    op.execute(f"""
        INSERT INTO accounting_periods (id, start_date, end_date, status)
        VALUES (
          '{uuid4()}',
          date_trunc('year', CURRENT_DATE)::date,
          (date_trunc('year', CURRENT_DATE) + interval '1 year - 1 day')::date,
          'open'
        )
        ON CONFLICT (start_date, end_date) DO NOTHING
    """)


def downgrade() -> None:
    # Only remove the auto-created period for the current year if it has
    # no journal entries (protecting financial immutability).
    op.execute("""
        DELETE FROM accounting_periods
        WHERE start_date = date_trunc('year', CURRENT_DATE)::date
          AND end_date = (date_trunc('year', CURRENT_DATE) + interval '1 year - 1 day')::date
          AND status = 'open'
          AND NOT EXISTS (
            SELECT 1 FROM journal_entries
            WHERE period_id = accounting_periods.id
          )
    """)
