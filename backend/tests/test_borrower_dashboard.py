"""Test suite for Borrower Portal Dashboard API (GET /api/v1/client/dashboard)."""

import secrets
import unittest
from datetime import date, timedelta

from httpx import ASGITransport, AsyncClient
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.database import get_db
from app.features.auth.service import create_token
from app.features.borrower_portal.models import (
    BorrowerAccount,
    BorrowerDevice,
    BorrowerRefreshToken,
)
from app.features.borrower_portal.service import create_borrower_access_token
from app.features.borrowers.models import Borrower
from app.features.loans.models import Installment, Loan
from app.features.payments.models import Payment
from app.features.users.models import User
from app.main import app
from tests.db_test_utils import get_verified_test_db_url


class TestBorrowerDashboardApi(unittest.IsolatedAsyncioTestCase):
    """Integration and security tests for Borrower Portal Dashboard API."""

    async def asyncSetUp(self) -> None:
        db_url = get_verified_test_db_url()
        self.engine = create_async_engine(db_url, echo=False, future=True)
        self.session_factory = async_sessionmaker(
            self.engine, class_=AsyncSession, expire_on_commit=False
        )

        async with self.session_factory() as db:
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

    async def test_authenticated_borrower_dashboard_success(self) -> None:
        suffix = secrets.token_hex(4)
        bor_id = f"bor-dash-{suffix}"
        acct_id = f"acct-dash-{suffix}"
        loan_id = f"loan-dash-{suffix}"
        user_id = f"usr-dash-{suffix}"

        today = date.today()

        async with self.session_factory() as db:
            officer = User(
                id=user_id,
                username=f"officer_{suffix}",
                hashed_password="hash",
                role="officer",
            )
            db.add(officer)

            borrower = Borrower(
                id=bor_id,
                first_name="Elena",
                last_name="Reyes",
                national_id=f"PH-DASH-{suffix}",
                phone=f"0917{suffix[:7]}",
                date_of_birth=date(1992, 5, 10),
                status="Active",
            )
            db.add(borrower)

            account = BorrowerAccount(
                id=acct_id,
                borrower_id=bor_id,
                phone_number=f"0917{suffix[:7]}",
                phone_number_normalized=f"+63917{suffix[:7]}",
                account_status="activated",
            )
            db.add(account)

            loan = Loan(
                id=loan_id,
                request_id=f"req-{suffix}",
                borrower_id=bor_id,
                created_by_user_id=user_id,
                policy_snapshot={"source": "test-fixture"},
                original_principal=10000,
                outstanding_principal=8500,
                monthly_rate=0.03,
                term_months=12,
                payments_per_month=1,
                number_of_payments=12,
                regular_payment_amount=850,
                status="Active",
                calculation_method="fixed_periodic_reducing_balance",
                start_date=today,
                first_due_date=today + timedelta(days=30),
                final_due_date=today + timedelta(days=360),
            )
            db.add(loan)

            inst = Installment(
                id=f"inst-{suffix}",
                loan_id=loan_id,
                installment_number=1,
                due_date=today + timedelta(days=14),
                expected_payment=850,
                expected_interest=250,
                expected_principal=600,
                expected_remaining_principal=7900,
                paid_amount=0,
                status="Scheduled",
            )
            db.add(inst)

            payment = Payment(
                id=f"pay-{suffix}",
                request_id=f"req-pay-{suffix}",
                loan_id=loan_id,
                recorded_by_user_id=user_id,
                amount=1500,
                entry_type="Payment",
                effective_date=today - timedelta(days=5),
            )
            db.add(payment)
            await db.commit()

        token = create_borrower_access_token(account)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get(
                "/api/v1/client/dashboard",
                headers={"Authorization": f"Bearer {token}"},
            )

        self.assertEqual(response.status_code, 200)
        data = response.json()

        self.assertEqual(data["borrower"]["id"], bor_id)
        self.assertEqual(data["borrower"]["firstName"], "Elena")
        self.assertEqual(data["borrower"]["lastName"], "Reyes")

        self.assertEqual(data["summary"]["activeLoanCount"], 1)
        self.assertEqual(float(data["summary"]["totalOutstandingBalance"]), 8500.0)
        self.assertEqual(float(data["summary"]["nextPaymentAmount"]), 850.0)
        self.assertIsNotNone(data["summary"]["nextDueDate"])
        self.assertEqual(float(data["summary"]["overdueAmount"]), 0.0)
        self.assertEqual(data["summary"]["loanStatus"], "active")
        self.assertEqual(data["summary"]["paymentStatus"], "current")

        self.assertIsNotNone(data["recentPayment"])
        self.assertEqual(float(data["recentPayment"]["amount"]), 1500.0)
        self.assertEqual(data["recentPayment"]["entryType"], "Payment")
        self.assertIsNotNone(data["lastUpdated"])

    async def test_unauthenticated_dashboard_rejected(self) -> None:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get("/api/v1/client/dashboard")
        self.assertEqual(response.status_code, 401)

    async def test_officer_token_rejected_on_dashboard(self) -> None:
        officer = User(
            id=f"usr-{secrets.token_hex(4)}",
            username=f"officer_{secrets.token_hex(4)}",
            hashed_password="hash",
            role="officer",
        )
        officer_token = create_token(officer, "access")

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get(
                "/api/v1/client/dashboard",
                headers={"Authorization": f"Bearer {officer_token}"},
            )
        self.assertEqual(response.status_code, 401)

    async def test_borrower_with_no_active_loans(self) -> None:
        suffix = secrets.token_hex(4)
        bor_id = f"bor-empty-{suffix}"
        acct_id = f"acct-empty-{suffix}"

        async with self.session_factory() as db:
            borrower = Borrower(
                id=bor_id,
                first_name="Marco",
                last_name="Santos",
                national_id=f"PH-EMP-{suffix}",
                phone=f"0918{suffix[:7]}",
                date_of_birth=date(1995, 8, 20),
                status="Active",
            )
            db.add(borrower)

            account = BorrowerAccount(
                id=acct_id,
                borrower_id=bor_id,
                phone_number=f"0918{suffix[:7]}",
                phone_number_normalized=f"+63918{suffix[:7]}",
                account_status="activated",
            )
            db.add(account)
            await db.commit()

        token = create_borrower_access_token(account)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get(
                "/api/v1/client/dashboard",
                headers={"Authorization": f"Bearer {token}"},
            )

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["borrower"]["firstName"], "Marco")
        self.assertEqual(data["summary"]["activeLoanCount"], 0)
        self.assertEqual(float(data["summary"]["totalOutstandingBalance"]), 0.0)
        self.assertEqual(float(data["summary"]["nextPaymentAmount"]), 0.0)
        self.assertIsNone(data["summary"]["nextDueDate"])
        self.assertEqual(data["summary"]["loanStatus"], "none")
        self.assertEqual(data["summary"]["paymentStatus"], "no_payment_due")
        self.assertIsNone(data["recentPayment"])

    async def test_overdue_borrower_dashboard(self) -> None:
        suffix = secrets.token_hex(4)
        bor_id = f"bor-overdue-{suffix}"
        acct_id = f"acct-overdue-{suffix}"
        loan_id = f"loan-overdue-{suffix}"
        user_id = f"usr-ovr-{suffix}"

        today = date.today()

        async with self.session_factory() as db:
            officer = User(
                id=user_id,
                username=f"officer_{suffix}",
                hashed_password="hash",
                role="officer",
            )
            db.add(officer)

            borrower = Borrower(
                id=bor_id,
                first_name="Carlos",
                last_name="Mendoza",
                national_id=f"PH-OVR-{suffix}",
                phone=f"0919{suffix[:7]}",
                date_of_birth=date(1988, 3, 15),
                status="Active",
            )
            db.add(borrower)

            account = BorrowerAccount(
                id=acct_id,
                borrower_id=bor_id,
                phone_number=f"0919{suffix[:7]}",
                phone_number_normalized=f"+63919{suffix[:7]}",
                account_status="activated",
            )
            db.add(account)

            loan = Loan(
                id=loan_id,
                request_id=f"req-ovr-{suffix}",
                borrower_id=bor_id,
                created_by_user_id=user_id,
                policy_snapshot={"source": "test-fixture"},
                original_principal=5000,
                outstanding_principal=5000,
                monthly_rate=0.03,
                term_months=6,
                payments_per_month=1,
                number_of_payments=6,
                regular_payment_amount=900,
                status="Overdue",
                calculation_method="fixed_periodic_reducing_balance",
                start_date=today - timedelta(days=60),
                first_due_date=today - timedelta(days=30),
                final_due_date=today + timedelta(days=120),
            )
            db.add(loan)

            overdue_inst = Installment(
                id=f"inst-ovr-{suffix}",
                loan_id=loan_id,
                installment_number=1,
                due_date=today - timedelta(days=10),
                expected_payment=900,
                expected_interest=150,
                expected_principal=750,
                expected_remaining_principal=4250,
                paid_amount=0,
                status="Overdue",
            )
            db.add(overdue_inst)
            await db.commit()

        token = create_borrower_access_token(account)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get(
                "/api/v1/client/dashboard",
                headers={"Authorization": f"Bearer {token}"},
            )

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["summary"]["activeLoanCount"], 1)
        self.assertEqual(float(data["summary"]["overdueAmount"]), 900.0)
        self.assertEqual(data["summary"]["loanStatus"], "overdue")
        self.assertEqual(data["summary"]["paymentStatus"], "overdue")

    async def test_openapi_schema_contains_dashboard(self) -> None:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get("/openapi.json")

        self.assertEqual(response.status_code, 200)
        paths = response.json().get("paths", {})
        self.assertIn("/api/v1/client/dashboard", paths)
        self.assertIn("get", paths["/api/v1/client/dashboard"])
