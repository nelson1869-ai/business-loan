"""Integration tests for Owner Draft Loan Approve and Approve & Activate workflows."""

import unittest
from datetime import date
from decimal import Decimal
from unittest.mock import patch

from fastapi import HTTPException
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from uuid import uuid4

from app.features.accounting.models import JournalEntry
from app.features.approvals.models import ApprovalRequest  # noqa: F401
from app.features.borrower_portal.models import BorrowerAccount, BorrowerNotification
from app.features.borrowers.models import Borrower
from app.features.loans import router as loan_router
from app.features.loans import service as loan_service
from app.features.loans.models import Loan
from app.features.loans.schemas import LoanCreate
from app.features.users.models import User
from app.features.write_offs.models import LoanWriteOff  # noqa: F401
from tests.db_test_utils import get_verified_test_db_url


class TestOwnerLoanApprovalWorkflow(unittest.IsolatedAsyncioTestCase):
    """Test suite for Owner Loan Approval and Approve & Activate lifecycle transitions."""

    async def asyncSetUp(self) -> None:
        """Initialize database session for testing."""
        self.db_url = get_verified_test_db_url()
        self.engine = create_async_engine(self.db_url, echo=False)
        self.SessionLocal = async_sessionmaker(
            bind=self.engine, class_=AsyncSession, expire_on_commit=False
        )
        self.db: AsyncSession = self.SessionLocal()

        self.owner_id = str(uuid4())
        self.borrower_id = str(uuid4())
        self.borrower_account_id = str(uuid4())

        # Seed Owner user
        self.owner = User(
            id=self.owner_id,
            username=f"owner_{self.owner_id[:8]}",
            hashed_password="hashed_password",
            role="admin",
        )
        # Seed Borrower
        self.borrower = Borrower(
            id=self.borrower_id,
            first_name="Juan",
            last_name="Dela Cruz",
            national_id=f"NAT-{self.borrower_id[:8]}",
            phone="+639170001122",
            phone_normalized=f"+63917{self.borrower_id[:6].replace('-', '0')}",
            date_of_birth=date(1990, 1, 1),
            status="Active",
        )
        # Seed Borrower Account
        self.borrower_account = BorrowerAccount(
            id=self.borrower_account_id,
            borrower_id=self.borrower_id,
            phone_number="+639170001122",
            phone_number_normalized=f"+63917{self.borrower_id[:6].replace('-', '0')}",
            account_status="activated",
        )

        self.db.add_all([self.owner, self.borrower, self.borrower_account])
        await self.db.commit()

    async def asyncTearDown(self) -> None:
        """Rollback session, truncate test tables, and dispose engine."""
        await self.db.rollback()
        async with self.engine.begin() as conn:
            await conn.execute(text("TRUNCATE borrower_notifications, journal_lines, journal_entries, installments, loans, borrower_accounts, borrowers, users CASCADE"))
        await self.db.close()
        await self.engine.dispose()

    async def _create_draft_loan(self) -> Loan:
        """Helper to create a fresh Draft loan account."""
        payload = LoanCreate(
            borrower_id=self.borrower.id,
            original_principal=Decimal("10000.00"),
            monthly_rate=Decimal("0.10000000"),
            term_months=1,
            payments_per_month=1,
            start_date=date(2026, 1, 1),
            first_due_date=date(2026, 2, 1),
            repayment_structure="principal_plus_interest",
        )
        return await loan_service.create_loan(
            self.db, payload, self.owner, initial_status="Draft"
        )

    # 1. Owner can approve own Draft
    async def test_owner_can_approve_own_draft(self) -> None:
        loan = await self._create_draft_loan()

        resp = await loan_router.transition_one_loan(
            loan.id, "approve", self.db, self.owner
        )
        self.assertEqual(resp.action, "approve")
        self.assertEqual(resp.status, "Draft")

        # Reload loan
        updated_loan = await loan_service.get_loan(self.db, loan.id)
        self.assertIsNotNone(updated_loan.approved_at)
        self.assertEqual(updated_loan.approved_by_user_id, self.owner.id)
        self.assertEqual(updated_loan.status, "Draft")
        self.assertIsNone(updated_loan.disbursed_at)
        self.assertIsNone(updated_loan.activated_at)

    # 2. Approve does not post accounting journal
    async def test_approve_does_not_post_disbursement_journal(self) -> None:
        loan = await self._create_draft_loan()
        await loan_router.transition_one_loan(loan.id, "approve", self.db, self.owner)

        # Query journal entries
        journals = (
            (
                await self.db.execute(
                    select(JournalEntry).where(
                        JournalEntry.source_record_id == loan.id
                    )
                )
            )
            .scalars()
            .all()
        )
        self.assertEqual(len(journals), 0)

    # 3. Owner can Approve and Activate own Draft
    async def test_owner_can_approve_and_activate_own_draft(self) -> None:
        loan = await self._create_draft_loan()

        resp = await loan_router.transition_one_loan(
            loan.id, "approve_and_activate", self.db, self.owner
        )
        self.assertEqual(resp.action, "approve_and_activate")
        self.assertEqual(resp.status, "Active")

        # Reload loan
        updated_loan = await loan_service.get_loan(self.db, loan.id)
        self.assertIsNotNone(updated_loan.approved_at)
        self.assertEqual(updated_loan.approved_by_user_id, self.owner.id)
        self.assertIsNotNone(updated_loan.disbursed_at)
        self.assertEqual(updated_loan.disbursed_by_user_id, self.owner.id)
        self.assertIsNotNone(updated_loan.activated_at)
        self.assertEqual(updated_loan.status, "Active")

    # 4. Approve and Activate creates exactly ONE accounting disbursement journal
    async def test_approve_and_activate_creates_exactly_one_journal(self) -> None:
        loan = await self._create_draft_loan()
        await loan_router.transition_one_loan(
            loan.id, "approve_and_activate", self.db, self.owner
        )

        journals = (
            (
                await self.db.execute(
                    select(JournalEntry).where(
                        JournalEntry.source_record_id == loan.id
                    )
                )
            )
            .scalars()
            .all()
        )
        self.assertEqual(len(journals), 1)
        self.assertEqual(journals[0].source_type, "loan_disbursement")
        self.assertEqual(
            journals[0].idempotency_key, f"loan-disbursement:{loan.id}"
        )

    # 5. Installment schedule is preserved and not duplicated
    async def test_installments_are_not_duplicated_on_activation(self) -> None:
        loan = await self._create_draft_loan()
        initial_installments_count = len(loan.installments)

        await loan_router.transition_one_loan(
            loan.id, "approve_and_activate", self.db, self.owner
        )

        updated_loan = await loan_service.get_loan(self.db, loan.id)
        self.assertEqual(
            len(updated_loan.installments), initial_installments_count
        )
        self.assertEqual(
            len(updated_loan.installments), updated_loan.number_of_payments
        )

    # 6. Borrower notification created with original_principal and deduplicated
    async def test_borrower_notification_uses_original_principal_and_deduplicates(
        self,
    ) -> None:
        loan = await self._create_draft_loan()
        await loan_router.transition_one_loan(
            loan.id, "approve_and_activate", self.db, self.owner
        )

        notifications = (
            (
                await self.db.execute(
                    select(BorrowerNotification).where(
                        BorrowerNotification.borrower_id == self.borrower.id
                    )
                )
            )
            .scalars()
            .all()
        )
        self.assertEqual(len(notifications), 1)
        self.assertEqual(notifications[0].notification_type, "loan_activated")
        self.assertEqual(
            notifications[0].deduplication_key, f"loan_activated:{loan.id}"
        )
        self.assertIn("₱10,000.00", notifications[0].message)

    # 7. Repeated Approve returns 409 Conflict
    async def test_repeated_approve_returns_409(self) -> None:
        loan = await self._create_draft_loan()
        await loan_router.transition_one_loan(loan.id, "approve", self.db, self.owner)

        with self.assertRaises(HTTPException) as raised:
            await loan_router.transition_one_loan(
                loan.id, "approve", self.db, self.owner
            )
        self.assertEqual(raised.exception.status_code, 409)

    # 8. Repeated Approve & Activate returns 409 Conflict
    async def test_repeated_approve_and_activate_returns_409(self) -> None:
        loan = await self._create_draft_loan()
        await loan_router.transition_one_loan(
            loan.id, "approve_and_activate", self.db, self.owner
        )

        with self.assertRaises(HTTPException) as raised:
            await loan_router.transition_one_loan(
                loan.id, "approve_and_activate", self.db, self.owner
            )
        self.assertEqual(raised.exception.status_code, 409)

    # 9. Non-ValueError exception rolls back transaction completely
    async def test_downstream_failure_rolls_back_transaction_completely(self) -> None:
        loan = await self._create_draft_loan()
        loan_id = loan.id

        with patch(
            "app.features.loans.router.publish_outbox_event",
            side_effect=RuntimeError("Outbox broker unavailable"),
        ):
            with self.assertRaises(RuntimeError):
                await loan_router.transition_one_loan(
                    loan_id, "approve_and_activate", self.db, self.owner
                )

        # Verify loan remains in Draft state in DB
        self.db.expire_all()
        reloaded_loan = await loan_service.get_loan(self.db, loan_id)
        self.assertEqual(reloaded_loan.status, "Draft")
        self.assertIsNone(reloaded_loan.approved_at)
        self.assertIsNone(reloaded_loan.disbursed_at)
        self.assertIsNone(reloaded_loan.activated_at)

        # Verify 0 accounting journals persisted
        journals = (
            (
                await self.db.execute(
                    select(JournalEntry).where(
                        JournalEntry.source_record_id == loan_id
                    )
                )
            )
            .scalars()
            .all()
        )
        self.assertEqual(len(journals), 0)

    # 10. Borrower visibility: Active visible to borrower; Draft not exposed
    async def test_borrower_visibility_respects_active_status(self) -> None:
        loan = await self._create_draft_loan()

        # Draft loan is not returned in active list
        active_loans = await loan_service.list_loans(
            self.db, borrower_id=self.borrower.id, loan_status="Active"
        )
        self.assertEqual(len(active_loans), 0)

        # Activate loan
        await loan_router.transition_one_loan(
            loan.id, "approve_and_activate", self.db, self.owner
        )

        # Now active loan is visible
        active_loans_after = await loan_service.list_loans(
            self.db, borrower_id=self.borrower.id, loan_status="Active"
        )
        self.assertEqual(len(active_loans_after), 1)
        self.assertEqual(active_loans_after[0].id, loan.id)


if __name__ == "__main__":
    unittest.main()
