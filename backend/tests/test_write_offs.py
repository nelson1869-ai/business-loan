"""Approved write-off and recovery financial-integrity tests."""

import unittest
from datetime import date
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

from app.features.loans.models import Loan
from app.features.write_offs.models import LoanWriteOff, WriteOffRecovery
from app.features.write_offs.schemas import RecoveryCreate, WriteOffCreate
from app.features.write_offs.service import record_recovery, write_off_loan


def _loan() -> Loan:
    return Loan(
        id="loan-1",
        request_id="request-1",
        borrower_id="borrower-1",
        created_by_user_id="maker-1",
        policy_snapshot={"source": "test"},
        original_principal=Decimal("1000.00"),
        outstanding_principal=Decimal("700.00"),
        monthly_rate=Decimal("0.05"),
        term_months=2,
        payments_per_month=1,
        number_of_payments=2,
        regular_payment_amount=Decimal("550.00"),
        calculation_method="fixed_periodic_reducing_balance",
        start_date=date(2026, 1, 1),
        first_due_date=date(2026, 2, 1),
        final_due_date=date(2026, 3, 1),
        status="Defaulted",
    )


class WriteOffTests(unittest.IsolatedAsyncioTestCase):
    async def test_write_off_consumes_approval_and_posts_full_balance(self) -> None:
        loan = _loan()
        db = MagicMock()
        db.scalar = AsyncMock(return_value=loan)
        db.flush = AsyncMock()
        payload = WriteOffCreate(
            approval_request_id="00000000-0000-4000-8000-000000000901",
            amount=Decimal("700.00"),
            effective_date=date(2026, 4, 1),
            reason="Documented uncollectible balance",
        )
        with (
            patch(
                "app.features.write_offs.service.consume_approved_request",
                new=AsyncMock(),
            ) as consume,
            patch(
                "app.features.write_offs.service.post_journal", new=AsyncMock()
            ) as post,
        ):
            result = await write_off_loan(
                db, loan.id, payload, SimpleNamespace(id="maker-1")
            )
        self.assertEqual(result.amount, Decimal("700.00"))
        self.assertEqual(loan.outstanding_principal, Decimal("0.00"))
        self.assertEqual(loan.status, "WrittenOff")
        consume.assert_awaited_once()
        post.assert_awaited_once()

    async def test_partial_write_off_is_rejected(self) -> None:
        db = MagicMock()
        db.scalar = AsyncMock(return_value=_loan())
        with self.assertRaisesRegex(ValueError, "full outstanding"):
            await write_off_loan(
                db,
                "loan-1",
                WriteOffCreate(
                    approval_request_id="00000000-0000-4000-8000-000000000901",
                    amount=Decimal("699.99"),
                    effective_date=date(2026, 4, 1),
                    reason="Partial amount",
                ),
                SimpleNamespace(id="maker-1"),
            )

    async def test_recovery_cannot_exceed_written_off_principal(self) -> None:
        write_off = LoanWriteOff(
            id="write-off-1",
            loan_id="loan-1",
            approval_request_id="approval-1",
            amount=Decimal("700.00"),
            effective_date=date(2026, 4, 1),
            reason="Uncollectible",
            written_off_by_user_id="maker-1",
        )
        write_off.recoveries = [
            WriteOffRecovery(
                id="recovery-1",
                request_id="recovery-request-1",
                write_off_id=write_off.id,
                amount=Decimal("650.00"),
                effective_date=date(2026, 4, 15),
                recorded_by_user_id="collector-1",
            )
        ]
        db = MagicMock()
        db.scalar = AsyncMock(side_effect=[None, write_off])
        with self.assertRaisesRegex(ValueError, "exceeds"):
            await record_recovery(
                db,
                "loan-1",
                RecoveryCreate(
                    request_id="00000000-0000-4000-8000-000000000902",
                    amount=Decimal("50.01"),
                    effective_date=date(2026, 5, 1),
                ),
                SimpleNamespace(id="collector-1"),
            )
