"""Integration and security test suite for Borrower Portal Payments & Receipts API."""

import secrets
import unittest
from datetime import date, timedelta
from decimal import Decimal

from httpx import ASGITransport, AsyncClient
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.database import get_db
from app.features.borrower_portal.models import (
    BorrowerAccount,
    BorrowerDevice,
    BorrowerRefreshToken,
)
from app.features.borrower_portal.service import create_borrower_access_token
from app.features.borrowers.models import Borrower
from app.features.loans.models import Installment, Loan
from app.features.payments.models import Payment, PaymentAllocation
from app.features.users.models import User
from app.main import app
from tests.db_test_utils import get_verified_test_db_url


class TestBorrowerPaymentsApi(unittest.IsolatedAsyncioTestCase):
    """Integration and security tests for Borrower Portal Payments & Receipts API."""

    async def asyncSetUp(self) -> None:
        db_url = get_verified_test_db_url()
        self.engine = create_async_engine(db_url, echo=False, future=True)
        self.session_factory = async_sessionmaker(
            self.engine, class_=AsyncSession, expire_on_commit=False
        )

        async with self.session_factory() as db:
            await db.execute(delete(PaymentAllocation))
            await db.execute(delete(Payment))
            await db.execute(delete(Installment))
            await db.execute(delete(Loan))
            await db.execute(delete(BorrowerRefreshToken))
            await db.execute(delete(BorrowerDevice))
            await db.execute(delete(BorrowerAccount))
            await db.execute(delete(Borrower))
            await db.execute(delete(User))
            await db.commit()

        async def _override_get_db():
            async with self.session_factory() as session:
                yield session

        app.dependency_overrides[get_db] = _override_get_db

    async def asyncTearDown(self) -> None:
        app.dependency_overrides.pop(get_db, None)
        async with self.session_factory() as db:
            await db.execute(delete(PaymentAllocation))
            await db.execute(delete(Payment))
            await db.execute(delete(Installment))
            await db.execute(delete(Loan))
            await db.execute(delete(BorrowerRefreshToken))
            await db.execute(delete(BorrowerDevice))
            await db.execute(delete(BorrowerAccount))
            await db.execute(delete(Borrower))
            await db.execute(delete(User))
            await db.commit()
        await self.engine.dispose()

    async def test_borrower_loan_payments_history_success(self) -> None:
        suffix = secrets.token_hex(4)
        bor_id = f"bor-pmt-{suffix}"
        acct_id = f"acct-pmt-{suffix}"
        user_id = f"usr-pmt-{suffix}"
        loan_id = f"loan-pmt-{suffix}"
        pmt_id = f"pmt-{suffix}"
        today = date.today()

        async with self.session_factory() as db:
            user = User(
                id=user_id,
                username=f"user_pmt_{suffix}",
                hashed_password="hash",
                role="officer",
            )
            db.add(user)

            borrower = Borrower(
                id=bor_id,
                first_name="Payment",
                last_name="History",
                national_id=f"PH-PMT-{suffix}",
                phone=f"0940{suffix[:7]}",
                date_of_birth=date(1992, 2, 2),
                status="Active",
            )
            db.add(borrower)

            account = BorrowerAccount(
                id=acct_id,
                borrower_id=bor_id,
                phone_number=f"0940{suffix[:7]}",
                phone_number_normalized=f"+63940{suffix[:7]}",
                account_status="activated",
            )
            db.add(account)

            loan = Loan(
                id=loan_id,
                request_id=secrets.token_hex(18),
                borrower_id=bor_id,
                created_by_user_id=user_id,
                policy_snapshot={"source": "test-fixture"},
                original_principal=5000,
                outstanding_principal=4000,
                monthly_rate=0.02,
                term_months=5,
                payments_per_month=1,
                number_of_payments=5,
                regular_payment_amount=1020,
                status="Active",
                calculation_method="fixed_periodic_reducing_balance",
                start_date=today - timedelta(days=30),
                first_due_date=today,
                final_due_date=today + timedelta(days=120),
            )
            db.add(loan)

            pmt = Payment(
                id=pmt_id,
                request_id=secrets.token_hex(18),
                loan_id=loan_id,
                recorded_by_user_id=user_id,
                entry_type="Payment",
                amount=Decimal("1020.00"),
                effective_date=today,
                created_at=date.today(),
            )
            db.add(pmt)

            alloc = PaymentAllocation(
                id=f"alloc-{suffix}",
                payment_id=pmt_id,
                interest_before=Decimal("20.00"),
                principal_before=Decimal("5000.00"),
                applied_interest=Decimal("20.00"),
                applied_principal=Decimal("1000.00"),
                unapplied_credit=Decimal("0.00"),
                interest_after=Decimal("0.00"),
                principal_after=Decimal("4000.00"),
                overdue_days=0,
                scheduled_period_days=30,
            )
            db.add(alloc)
            await db.commit()

        token = create_borrower_access_token(account)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            res = await client.get(
                f"/api/v1/client/loans/{loan_id}/payments",
                headers={"Authorization": f"Bearer {token}"},
            )

        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data["totalCount"], 1)
        self.assertEqual(len(data["items"]), 1)
        item = data["items"][0]
        self.assertEqual(item["id"], pmt_id)
        self.assertEqual(item["amount"], "1020.00")
        self.assertTrue(item["receiptNumber"].startswith("RCPT-"))

    async def test_borrower_payment_receipt_detail_success(self) -> None:
        suffix = secrets.token_hex(4)
        bor_id = f"bor-rcp-{suffix}"
        acct_id = f"acct-rcp-{suffix}"
        user_id = f"usr-rcp-{suffix}"
        loan_id = f"loan-rcp-{suffix}"
        pmt_id = f"pmt-rcp-{suffix}"
        today = date.today()

        async with self.session_factory() as db:
            user = User(
                id=user_id,
                username=f"user_rcp_{suffix}",
                hashed_password="hash",
                role="officer",
            )
            db.add(user)

            borrower = Borrower(
                id=bor_id,
                first_name="Receipt",
                last_name="Test",
                national_id=f"PH-RCP-{suffix}",
                phone=f"0941{suffix[:7]}",
                date_of_birth=date(1991, 1, 1),
                status="Active",
            )
            db.add(borrower)

            account = BorrowerAccount(
                id=acct_id,
                borrower_id=bor_id,
                phone_number=f"0941{suffix[:7]}",
                phone_number_normalized=f"+63941{suffix[:7]}",
                account_status="activated",
            )
            db.add(account)

            loan = Loan(
                id=loan_id,
                request_id=secrets.token_hex(18),
                borrower_id=bor_id,
                created_by_user_id=user_id,
                policy_snapshot={"source": "test-fixture"},
                original_principal=3000,
                outstanding_principal=2000,
                monthly_rate=0.02,
                term_months=3,
                payments_per_month=1,
                number_of_payments=3,
                regular_payment_amount=1020,
                status="Active",
                calculation_method="fixed_periodic_reducing_balance",
                start_date=today - timedelta(days=30),
                first_due_date=today,
                final_due_date=today + timedelta(days=60),
            )
            db.add(loan)

            pmt = Payment(
                id=pmt_id,
                request_id=secrets.token_hex(18),
                loan_id=loan_id,
                recorded_by_user_id=user_id,
                entry_type="Payment",
                amount=Decimal("1020.00"),
                effective_date=today,
            )
            db.add(pmt)

            alloc = PaymentAllocation(
                id=f"alloc-{suffix}",
                payment_id=pmt_id,
                interest_before=Decimal("20.00"),
                principal_before=Decimal("3000.00"),
                applied_interest=Decimal("20.00"),
                applied_principal=Decimal("1000.00"),
                unapplied_credit=Decimal("0.00"),
                interest_after=Decimal("0.00"),
                principal_after=Decimal("2000.00"),
                overdue_days=0,
                scheduled_period_days=30,
            )
            db.add(alloc)
            await db.commit()

        token = create_borrower_access_token(account)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            res = await client.get(
                f"/api/v1/client/payments/{pmt_id}/receipt",
                headers={"Authorization": f"Bearer {token}"},
            )

        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data["paymentId"], pmt_id)
        self.assertEqual(data["amountReceived"], "1020.00")
        self.assertEqual(data["principalPaid"], "1000.00")
        self.assertEqual(data["interestPaid"], "20.00")
        self.assertEqual(data["remainingBalance"], "2000.00")
        self.assertEqual(data["status"], "posted")

    async def test_borrower_payment_receipt_unauthorized_other_borrower(self) -> None:
        suffix = secrets.token_hex(4)
        bor_id1 = f"bor1-p-{suffix}"
        bor_id2 = f"bor2-p-{suffix}"
        acct_id2 = f"acct2-p-{suffix}"
        user_id = f"usr2-p-{suffix}"
        loan_id = f"loan2-p-{suffix}"
        pmt_id = f"pmt2-p-{suffix}"
        today = date.today()

        async with self.session_factory() as db:
            user = User(
                id=user_id,
                username=f"user2_p_{suffix}",
                hashed_password="hash",
                role="officer",
            )
            db.add(user)

            bor1 = Borrower(
                id=bor_id1,
                first_name="Owner",
                last_name="Payment",
                national_id=f"PH-O1P-{suffix}",
                phone=f"0942{suffix[:7]}",
                date_of_birth=date(1990, 1, 1),
                status="Active",
            )
            bor2 = Borrower(
                id=bor_id2,
                first_name="Attacker",
                last_name="Payment",
                national_id=f"PH-O2P-{suffix}",
                phone=f"0943{suffix[:7]}",
                date_of_birth=date(1991, 2, 2),
                status="Active",
            )
            db.add_all([bor1, bor2])

            account2 = BorrowerAccount(
                id=acct_id2,
                borrower_id=bor_id2,
                phone_number=f"0943{suffix[:7]}",
                phone_number_normalized=f"+63943{suffix[:7]}",
                account_status="activated",
            )
            db.add(account2)

            loan = Loan(
                id=loan_id,
                request_id=secrets.token_hex(18),
                borrower_id=bor_id1,
                created_by_user_id=user_id,
                policy_snapshot={"source": "test-fixture"},
                original_principal=1000,
                outstanding_principal=1000,
                monthly_rate=0.02,
                term_months=1,
                payments_per_month=1,
                number_of_payments=1,
                regular_payment_amount=1020,
                status="Active",
                calculation_method="fixed_periodic_reducing_balance",
                start_date=today,
                first_due_date=today + timedelta(days=30),
                final_due_date=today + timedelta(days=30),
            )
            db.add(loan)

            pmt = Payment(
                id=pmt_id,
                request_id=secrets.token_hex(18),
                loan_id=loan_id,
                recorded_by_user_id=user_id,
                entry_type="Payment",
                amount=Decimal("1020.00"),
                effective_date=today,
            )
            db.add(pmt)
            await db.commit()

        token2 = create_borrower_access_token(account2)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            res = await client.get(
                f"/api/v1/client/payments/{pmt_id}/receipt",
                headers={"Authorization": f"Bearer {token2}"},
            )

        self.assertEqual(res.status_code, 404)
