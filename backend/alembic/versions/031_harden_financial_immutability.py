"""Enforce balanced journals and immutable approved policy versions.

Revision ID: 031
Revises: 030
"""

from collections.abc import Sequence

from alembic import op

revision: str = "031"
down_revision: str | None = "030"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.drop_constraint("ck_users_role", "users", type_="check")
    op.create_check_constraint(
        "ck_users_role",
        "users",
        "role IN ('admin', 'owner', 'manager', 'officer', 'loan_officer', "
        "'collector', 'cashier', 'auditor', 'read_only_support')",
    )

    op.execute("""
        CREATE FUNCTION enforce_policy_version_immutability() RETURNS trigger AS $$
        BEGIN
          IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION 'loan policy versions are immutable';
          END IF;

          IF OLD.status = 'draft'
             AND NEW.status = 'active'
             AND NEW.approved_by_user_id IS NOT NULL
             AND NEW.approved_at IS NOT NULL
             AND (to_jsonb(NEW) - ARRAY['status', 'approved_by_user_id', 'approved_at'])
                 = (to_jsonb(OLD) - ARRAY['status', 'approved_by_user_id', 'approved_at']) THEN
            RETURN NEW;
          END IF;

          IF OLD.status = 'active'
             AND NEW.status = 'retired'
             AND (to_jsonb(NEW) - 'status') = (to_jsonb(OLD) - 'status') THEN
            RETURN NEW;
          END IF;

          RAISE EXCEPTION 'loan policy versions are immutable';
        END;
        $$ LANGUAGE plpgsql
    """)
    op.execute("""
        CREATE TRIGGER trg_loan_policy_versions_immutable
        BEFORE UPDATE OR DELETE ON loan_policy_versions
        FOR EACH ROW EXECUTE FUNCTION enforce_policy_version_immutability()
    """)

    op.execute("""
        CREATE FUNCTION enforce_balanced_journal() RETURNS trigger AS $$
        DECLARE
          target_entry_id varchar(36);
          line_count integer;
          debit_total numeric(18, 2);
          credit_total numeric(18, 2);
        BEGIN
          IF TG_TABLE_NAME = 'journal_lines' THEN
            target_entry_id := NEW.journal_entry_id;
          ELSE
            target_entry_id := NEW.id;
          END IF;
          SELECT COUNT(*), COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0)
          INTO line_count, debit_total, credit_total
          FROM journal_lines
          WHERE journal_entry_id = target_entry_id;

          IF line_count < 2 OR debit_total <> credit_total THEN
            RAISE EXCEPTION 'journal entry % is not balanced', target_entry_id;
          END IF;
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql
    """)
    op.execute("""
        CREATE CONSTRAINT TRIGGER trg_journal_entries_balanced
        AFTER INSERT ON journal_entries
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION enforce_balanced_journal()
    """)
    op.execute("""
        CREATE CONSTRAINT TRIGGER trg_journal_lines_balanced
        AFTER INSERT ON journal_lines
        DEFERRABLE INITIALLY DEFERRED
        FOR EACH ROW EXECUTE FUNCTION enforce_balanced_journal()
    """)


def downgrade() -> None:
    op.execute("DROP TRIGGER trg_journal_lines_balanced ON journal_lines")
    op.execute("DROP TRIGGER trg_journal_entries_balanced ON journal_entries")
    op.execute("DROP FUNCTION enforce_balanced_journal()")
    op.execute(
        "DROP TRIGGER trg_loan_policy_versions_immutable ON loan_policy_versions"
    )
    op.execute("DROP FUNCTION enforce_policy_version_immutability()")
    op.drop_constraint("ck_users_role", "users", type_="check")
    op.create_check_constraint("ck_users_role", "users", "role IN ('officer', 'admin')")
