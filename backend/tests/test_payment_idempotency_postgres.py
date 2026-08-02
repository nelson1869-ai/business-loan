"""Opt-in PostgreSQL integration test for concurrent payment retries."""

import asyncio
import os
import unittest
from datetime import date
from decimal import Decimal
from uuid import uuid4

from sqlalchemy import func, select

from app.core.database import AsyncSessionFactory, engine
from app.features.approvals.service import create_request, decide_request
from app.features.borrowers.models import Borrower
from app.features.loans.models import Installment, Loan
from app.features.payments.models import Payment
from app.features.payments.router import confirm_one_payment, reverse_one_payment
from app.features.payments.schemas import (
    PaymentCreate,
    PaymentPreviewRequest,
    PaymentReversalCreate,
)
from app.features.payments.service import preview_payment
from app.features.users.models import User


@unittest.skipUnless(
    os.getenv("RUN_POSTGRES_INTEGRATION") == "1",
    "set RUN_POSTGRES_INTEGRATION=1 to use the configured PostgreSQL database",
)
class PostgreSqlPaymentIdempotencyTests(unittest.IsolatedAsyncioTestCase):
    """Prove a concurrent retry changes the balance exactly once."""

    async def asyncSetUp(self) -> None:
        suffix = uuid4().hex
        phone = f"0918{uuid4().int % 10_000_000:07d}"
        self.user_id = str(uuid4())
        self.checker_id = str(uuid4())
        self.borrower_id = str(uuid4())
        self.loan_id = str(uuid4())
        self.installment_id = str(uuid4())
        self.request_id = str(uuid4())
        async with AsyncSessionFactory() as db:
            db.add(
                User(
                    id=self.user_id,
                    username=f"payment-{suffix}",
                    hashed_password="test",
                    role="manager",
                )
            )
            db.add(
                User(
                    id=self.checker_id,
                    username=f"payment-checker-{suffix}",
                    hashed_password="test",
                    role="owner",
                )
            )
            db.add(
                Borrower(
                    id=self.borrower_id,
                    first_name="Payment",
                    last_name="Test",
                    national_id=f"payment-{suffix}",
                    phone=phone,
                    date_of_birth=date(1990, 1, 1),
                    status="Active",
                )
            )
            db.add(
                Loan(
                    id=self.loan_id,
                    request_id=str(uuid4()),
                    borrower_id=self.borrower_id,
                    created_by_user_id=self.user_id,
                    policy_snapshot={"source": "test-fixture"},
                    original_principal=Decimal("1000.00"),
                    outstanding_principal=Decimal("1000.00"),
                    monthly_rate=Decimal("0.10"),
                    term_months=1,
                    payments_per_month=1,
                    number_of_payments=1,
                    regular_payment_amount=Decimal("1100.00"),
                    calculation_method="fixed_periodic_reducing_balance",
                    start_date=date(2026, 8, 1),
                    first_due_date=date(2026, 8, 31),
                    final_due_date=date(2026, 8, 31),
                    status="Active",
                )
            )
            db.add(
                Installment(
                    id=self.installment_id,
                    loan_id=self.loan_id,
                    installment_number=1,
                    due_date=date(2026, 8, 31),
                    expected_payment=Decimal("1100.00"),
                    expected_interest=Decimal("100.00"),
                    expected_principal=Decimal("1000.00"),
                    expected_remaining_principal=Decimal("0.00"),
                    paid_amount=Decimal("0.00"),
                    status="Scheduled",
                )
            )
            await db.commit()

    async def asyncTearDown(self) -> None:
        # Posted accounting journals intentionally prevent deleting their actor.
        # This suite runs only against a disposable *_test database.
        await engine.dispose()

    async def test_concurrent_retry_records_and_allocates_once(self) -> None:
        payload = PaymentCreate.model_validate(
            {
                "requestId": self.request_id,
                "amount": "200.00",
                "effectiveDate": "2026-08-31",
            }
        )
        first, second = await asyncio.gather(
            self._submit(payload), self._submit(payload)
        )
        self.assertEqual(first.id, second.id)
        async with AsyncSessionFactory() as db:
            count = await db.scalar(
                select(func.count())
                .select_from(Payment)
                .where(Payment.request_id == self.request_id)
            )
            loan = await db.get(Loan, self.loan_id)
        self.assertEqual(count, 1)
        self.assertIsNotNone(loan)
        self.assertEqual(loan.outstanding_principal, Decimal("900.00"))

    async def test_concurrent_reversal_restores_balance_once(self) -> None:
        payment = await self._submit(
            PaymentCreate.model_validate(
                {
                    "requestId": self.request_id,
                    "amount": "200.00",
                    "effectiveDate": "2026-08-31",
                }
            )
        )
        reversal_request_id = str(uuid4())
        async with AsyncSessionFactory() as db:
            maker = await db.get(User, self.user_id)
            checker = await db.get(User, self.checker_id)
            assert maker is not None and checker is not None
            approval = await create_request(
                db,
                action="payment.reverse",
                entity_type="payment",
                entity_id=payment.id,
                maker=maker,
                reason="Integration test correction",
            )
            await decide_request(
                db,
                approval.id,
                checker,
                "approved",
                "Verified test correction",
            )
            await db.commit()
        payload = PaymentReversalCreate.model_validate(
            {
                "requestId": reversal_request_id,
                "effectiveDate": "2026-09-01",
                "reason": "Integration test correction",
                "approvalRequestId": approval.id,
            }
        )

        first, second = await asyncio.gather(
            self._reverse(payment.id, payload),
            self._reverse(payment.id, payload),
        )

        self.assertEqual(first.id, second.id)
        async with AsyncSessionFactory() as db:
            reversal_count = await db.scalar(
                select(func.count())
                .select_from(Payment)
                .where(Payment.request_id == reversal_request_id)
            )
            loan = await db.get(Loan, self.loan_id)
            installment = await db.get(Installment, self.installment_id)
        self.assertEqual(reversal_count, 1)
        self.assertIsNotNone(loan)
        self.assertIsNotNone(installment)
        self.assertEqual(loan.outstanding_principal, Decimal("1000.00"))
        self.assertEqual(loan.status, "Overdue")
        self.assertEqual(installment.paid_amount, Decimal("0.00"))
        self.assertEqual(installment.status, "Overdue")
        async with AsyncSessionFactory() as db:
            preview = await preview_payment(
                db,
                self.loan_id,
                PaymentPreviewRequest.model_validate(
                    {"amount": "100.00", "effectiveDate": "2026-09-02"}
                ),
            )
            await db.rollback()
        self.assertEqual(preview.accrual_start_date, date(2026, 8, 31))
        self.assertEqual(preview.principal_before, Decimal("1000.00"))
        self.assertEqual(preview.total_interest_before, Decimal("106.67"))

    async def _submit(self, payload: PaymentCreate):
        async with AsyncSessionFactory() as db:
            user = await db.get(User, self.user_id)
            assert user is not None
            return await confirm_one_payment(self.loan_id, payload, db, user)

    async def _reverse(self, payment_id: str, payload: PaymentReversalCreate):
        async with AsyncSessionFactory() as db:
            user = await db.get(User, self.user_id)
            assert user is not None
            return await reverse_one_payment(
                self.loan_id,
                payment_id,
                payload,
                db,
                user,
            )


if __name__ == "__main__":
    unittest.main()
