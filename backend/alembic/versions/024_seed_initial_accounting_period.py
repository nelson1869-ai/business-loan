"""Seed the initial open calendar-year accounting period.

Revision ID: 024
Revises: 023
"""

from collections.abc import Sequence

from alembic import op

revision: str = "024"
down_revision: str | None = "023"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # This only makes the deployment year operational. Future periods must be
    # opened deliberately; posting never bypasses a closed or missing period.
    op.execute("""
        INSERT INTO accounting_periods (id, start_date, end_date, status)
        VALUES (
          '00000000-0000-4000-8000-000000000001',
          date_trunc('year', CURRENT_DATE)::date,
          (date_trunc('year', CURRENT_DATE) + interval '1 year - 1 day')::date,
          'open'
        )
        ON CONFLICT (start_date, end_date) DO NOTHING
    """)


def downgrade() -> None:
    op.execute("""
        DELETE FROM accounting_periods
        WHERE id = '00000000-0000-4000-8000-000000000001'
          AND status = 'open'
          AND NOT EXISTS (
            SELECT 1 FROM journal_entries
            WHERE period_id = accounting_periods.id
          )
    """)
