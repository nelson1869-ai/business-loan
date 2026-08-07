"""PostgreSQL regression tests for financial immutability constraints."""

import unittest
from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from tests.db_test_utils import get_verified_test_db_url


class FinancialDatabaseGuardTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        self.engine = create_async_engine(get_verified_test_db_url())
        self.sessions = async_sessionmaker(
            self.engine, class_=AsyncSession, expire_on_commit=False
        )

    async def asyncTearDown(self) -> None:
        await self.engine.dispose()

    async def test_unbalanced_journal_is_rejected_at_transaction_boundary(self) -> None:
        async with self.sessions() as db:
            actor_id = str(uuid4())
            entry_id = str(uuid4())
            await db.execute(
                text(
                    "INSERT INTO users (id, username, hashed_password, role) "
                    "VALUES (:id, :username, 'test-only', 'admin')"
                ),
                {"id": actor_id, "username": f"journal-guard-{actor_id}"},
            )
            period_id = await db.scalar(
                text(
                    "SELECT id FROM accounting_periods "
                    "WHERE status = 'open' ORDER BY start_date LIMIT 1"
                )
            )
            if period_id is None:
                period_id = str(uuid4())
                await db.execute(
                    text(
                        "INSERT INTO accounting_periods (id, start_date, end_date, status) "
                        "VALUES (:id, '2026-01-01', '2026-12-31', 'open')"
                    ),
                    {"id": period_id},
                )
            cash_account_id = await db.scalar(
                text("SELECT id FROM accounts WHERE code = '1000'")
            )
            await db.execute(
                text(
                    "INSERT INTO journal_entries "
                    "(id, period_id, currency, posted_at, actor_user_id, source_type, "
                    "source_record_id, idempotency_key, description) VALUES "
                    "(:id, :period, 'PHP', :posted, :actor, 'guard_test', :source, "
                    ":key, 'unbalanced regression test')"
                ),
                {
                    "id": entry_id,
                    "period": period_id,
                    "posted": datetime.now(UTC),
                    "actor": actor_id,
                    "source": str(uuid4()),
                    "key": str(uuid4()),
                },
            )
            await db.execute(
                text(
                    "INSERT INTO journal_lines "
                    "(id, journal_entry_id, line_number, account_id, debit, credit, memo) "
                    "VALUES (:id, :entry, 1, :account, 10.00, 0.00, 'unbalanced')"
                ),
                {"id": str(uuid4()), "entry": entry_id, "account": cash_account_id},
            )
            with self.assertRaises(DBAPIError):
                await db.execute(text("SET CONSTRAINTS ALL IMMEDIATE"))
            await db.rollback()

    async def test_approved_policy_financial_fields_cannot_be_mutated(self) -> None:
        async with self.sessions() as db:
            maker_id = str(uuid4())
            checker_id = str(uuid4())
            policy_id = str(uuid4())
            for user_id, label in ((maker_id, "maker"), (checker_id, "checker")):
                await db.execute(
                    text(
                        "INSERT INTO users (id, username, hashed_password, role) "
                        "VALUES (:id, :username, 'test-only', 'admin')"
                    ),
                    {"id": user_id, "username": f"policy-{label}-{user_id}"},
                )
            await db.execute(
                text(
                    "INSERT INTO loan_policy_versions "
                    "(id, policy_name, version_number, status, currency, interest_method, "
                    "rate_period, minimum_rate, maximum_rate, rounding_policy, "
                    "payment_allocation_order, grace_period_configuration, "
                    "late_fee_configuration, early_settlement_configuration, "
                    "excess_payment_treatment, restructuring_policy, write_off_policy, "
                    "contract_template_version, effective_date, change_reason, "
                    "created_by_user_id) VALUES "
                    "(:id, :name, 1, 'draft', 'PHP', 'fixed_periodic_reducing_balance', "
                    "'monthly', 0.01, 0.10, '{}'::json, '[\"interest\",\"principal\"]'::json, "
                    "'{}'::json, '{}'::json, '{}'::json, '{}'::json, '{}'::json, "
                    "'{}'::json, 'v1', CURRENT_DATE, 'guard test', :maker)"
                ),
                {
                    "id": policy_id,
                    "name": f"Policy guard {policy_id}",
                    "maker": maker_id,
                },
            )
            await db.execute(
                text(
                    "UPDATE loan_policy_versions SET status = 'active', "
                    "approved_by_user_id = :checker, approved_at = now() WHERE id = :id"
                ),
                {"checker": checker_id, "id": policy_id},
            )
            with self.assertRaises(DBAPIError):
                await db.execute(
                    text(
                        "UPDATE loan_policy_versions SET maximum_rate = 0.20 "
                        "WHERE id = :id"
                    ),
                    {"id": policy_id},
                )
            await db.rollback()
