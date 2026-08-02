"""Add immutable double-entry accounting ledger.

Revision ID: 023
Revises: 022
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "023"
down_revision: str | None = "022"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "accounts",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("code", sa.String(32), nullable=False, unique=True),
        sa.Column("name", sa.String(160), nullable=False),
        sa.Column("category", sa.String(16), nullable=False),
        sa.Column("currency", sa.String(3), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.CheckConstraint(
            "category IN ('asset', 'liability', 'equity', 'income', 'expense')",
            name="ck_accounts_category",
        ),
        sa.CheckConstraint("currency ~ '^[A-Z]{3}$'", name="ck_accounts_currency"),
    )
    op.create_table(
        "accounting_periods",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=False),
        sa.Column("status", sa.String(16), nullable=False, server_default="open"),
        sa.Column(
            "closed_by_user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
        ),
        sa.Column("closed_at", sa.DateTime(timezone=True)),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint(
            "start_date", "end_date", name="uq_accounting_period_range"
        ),
        sa.CheckConstraint("end_date >= start_date", name="ck_accounting_period_dates"),
        sa.CheckConstraint(
            "status IN ('open', 'closed', 'locked')",
            name="ck_accounting_period_status",
        ),
    )
    op.create_table(
        "journal_entries",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "period_id",
            sa.String(36),
            sa.ForeignKey("accounting_periods.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("currency", sa.String(3), nullable=False),
        sa.Column("posted_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "actor_user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("source_type", sa.String(64), nullable=False),
        sa.Column("source_record_id", sa.String(64), nullable=False),
        sa.Column("idempotency_key", sa.String(255), nullable=False),
        sa.Column("request_id", sa.String(64)),
        sa.Column("description", sa.String(500), nullable=False),
        sa.Column("status", sa.String(16), nullable=False, server_default="posted"),
        sa.Column(
            "reconciliation_status",
            sa.String(16),
            nullable=False,
            server_default="unreconciled",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint("idempotency_key", name="uq_journal_idempotency_key"),
        sa.UniqueConstraint(
            "source_type", "source_record_id", name="uq_journal_source_reference"
        ),
        sa.CheckConstraint("currency ~ '^[A-Z]{3}$'", name="ck_journal_currency"),
        sa.CheckConstraint("status = 'posted'", name="ck_journal_posted_only"),
        sa.CheckConstraint(
            "reconciliation_status IN ('unreconciled', 'reconciled')",
            name="ck_journal_reconciliation_status",
        ),
    )
    op.create_index(
        "ix_journal_posted_currency",
        "journal_entries",
        ["posted_at", "currency"],
    )
    op.create_table(
        "journal_lines",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "journal_entry_id",
            sa.String(36),
            sa.ForeignKey("journal_entries.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("line_number", sa.Integer(), nullable=False),
        sa.Column(
            "account_id",
            sa.String(36),
            sa.ForeignKey("accounts.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("debit", sa.Numeric(18, 2), nullable=False),
        sa.Column("credit", sa.Numeric(18, 2), nullable=False),
        sa.Column("memo", sa.String(500), nullable=False, server_default=""),
        sa.UniqueConstraint(
            "journal_entry_id", "line_number", name="uq_journal_line_number"
        ),
        sa.CheckConstraint("line_number > 0", name="ck_journal_line_number"),
        sa.CheckConstraint(
            "(debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0)",
            name="ck_journal_line_one_side",
        ),
    )

    # Database protection complements service-level immutability. Corrections are
    # represented by new compensating entries, never mutations of posted history.
    op.execute("""
        CREATE FUNCTION prevent_posted_journal_mutation() RETURNS trigger AS $$
        BEGIN
          RAISE EXCEPTION 'posted journals are immutable';
        END;
        $$ LANGUAGE plpgsql
    """)
    for table in ("journal_entries", "journal_lines"):
        op.execute(f"""
            CREATE TRIGGER trg_{table}_immutable
            BEFORE UPDATE OR DELETE ON {table}
            FOR EACH ROW EXECUTE FUNCTION prevent_posted_journal_mutation()
        """)

    accounts = [
        ("1000", "Cash on hand", "asset"),
        ("1010", "Bank", "asset"),
        ("1100", "Loans receivable", "asset"),
        ("1110", "Interest receivable", "asset"),
        ("1120", "Fees receivable", "asset"),
        ("1200", "Allowance for doubtful accounts", "asset"),
        ("2000", "Unapplied borrower credit", "liability"),
        ("3000", "Owner capital", "equity"),
        ("4000", "Interest income", "income"),
        ("4010", "Fee income", "income"),
        ("4020", "Recoveries after write-off", "income"),
        ("5000", "Bad-debt expense", "expense"),
        ("5100", "Operating expenses", "expense"),
    ]
    account_table = sa.table(
        "accounts",
        sa.column("id", sa.String),
        sa.column("code", sa.String),
        sa.column("name", sa.String),
        sa.column("category", sa.String),
        sa.column("currency", sa.String),
        sa.column("is_active", sa.Boolean),
    )
    op.bulk_insert(
        account_table,
        [
            {
                "id": f"00000000-0000-4000-8000-{int(code):012d}",
                "code": code,
                "name": name,
                "category": category,
                "currency": "PHP",
                "is_active": True,
            }
            for code, name, category in accounts
        ],
    )


def downgrade() -> None:
    op.execute("DROP TRIGGER trg_journal_lines_immutable ON journal_lines")
    op.execute("DROP TRIGGER trg_journal_entries_immutable ON journal_entries")
    op.execute("DROP FUNCTION prevent_posted_journal_mutation()")
    op.drop_table("journal_lines")
    op.drop_index("ix_journal_posted_currency", table_name="journal_entries")
    op.drop_table("journal_entries")
    op.drop_table("accounting_periods")
    op.drop_table("accounts")
