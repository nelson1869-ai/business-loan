"""Test suite for Borrower Portal Loans API (GET /api/v1/client/loans & GET /api/v1/client/loans/{loanId})."""

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
    BorrowerInvitation,
    BorrowerOTP,
    BorrowerRefreshToken,
)
from app.features.borrower_portal.service import create_borrower_access_token
from app.features.borrowers.models import Borrower
from app.features.loans.models import Installment, Loan
from app.features.payments.models import Payment
from app.features.users.models import User
from app.main import app
from tests.db_test_utils import get_verified_test_db_url


class TestBorrowerLoansApi(unittest.IsolatedAsyncioTestCase):
    """Integration and security tests for Borrower Portal Loans endpoints."""

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
            await db.execute(delete(BorrowerOTP))
            await db.execute(delete(BorrowerInvitation))
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
            await db.execute(delete(BorrowerOTP))
            await db.execute(delete(BorrowerInvitation))
            await db.execute(delete(BorrowerAccount))
            await db.execute(delete(Borrower))
            await db.execute(delete(User))
            await db.commit()
        await self.engine.dispose()

    async def test_authenticated_borrower_loans_list(self) -> None:
        suffix = secrets.token_hex(4)
        bor_id = f"bor-lns-{suffix}"
        acct_id = f"acct-lns-{suffix}"
        user_id = f"usr-lns-{suffix}"
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
                first_name="Sofia",
                last_name="Cruz",
                national_id=f"PH-LNS-{suffix}",
                phone=f"0920{suffix[:7]}",
                date_of_birth=date(1990, 1, 1),
                status="Active",
            )
            db.add(borrower)

            account = BorrowerAccount(
                id=acct_id,
                borrower_id=bor_id,
                phone_number=f"0920{suffix[:7]}",
                phone_number_normalized=f"+63920{suffix[:7]}",
                account_status="active",
            )
            db.add(account)

            loan1 = Loan(
                id=f"loan-1-{suffix}",
                request_id=f"req-1-{suffix}",
                borrower_id=bor_id,
                created_by_user_id=user_id,
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
            db.add(loan1)

            inst1 = Installment(
                id=f"inst-1-{suffix}",
                loan_id=loan1.id,
                installment_number=1,
                due_date=today + timedelta(days=30),
                expected_payment=850,
                expected_interest=250,
                expected_principal=600,
                expected_remaining_principal=7900,
                paid_amount=0,
                status="Scheduled",
            )
            db.add(inst1)
            await db.commit()

        token = create_borrower_access_token(account)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get(
                "/api/v1/client/loans",
                headers={"Authorization": f"Bearer {token}"},
            )

        self.assertEqual(response.status_code, 200)
        data = response.json()

        self.assertIn("items", data)
        self.assertEqual(data["total"], 1)
        self.assertEqual(data["offset"], 0)
        self.assertEqual(data["limit"], 20)
        self.assertEqual(len(data["items"]), 1)

        item = data["items"][0]
        self.assertEqual(item["id"], f"loan-1-{suffix}")
        self.assertEqual(item["status"], "active")
        self.assertEqual(float(item["principalAmount"]), 10000.0)
        self.assertEqual(float(item["outstandingBalance"]), 8500.0)
        self.assertEqual(item["paymentFrequency"], "monthly")

    async def test_borrower_loans_empty(self) -> None:
        suffix = secrets.token_hex(4)
        bor_id = f"bor-emp-{suffix}"
        acct_id = f"acct-emp-{suffix}"

        async with self.session_factory() as db:
            borrower = Borrower(
                id=bor_id,
                first_name="No",
                last_name="Loans",
                national_id=f"PH-NOL-{suffix}",
                phone=f"0921{suffix[:7]}",
                date_of_birth=date(1993, 2, 2),
                status="Active",
            )
            db.add(borrower)

            account = BorrowerAccount(
                id=acct_id,
                borrower_id=bor_id,
                phone_number=f"0921{suffix[:7]}",
                phone_number_normalized=f"+63921{suffix[:7]}",
                account_status="active",
            )
            db.add(account)
            await db.commit()

        token = create_borrower_access_token(account)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get(
                "/api/v1/client/loans",
                headers={"Authorization": f"Bearer {token}"},
            )

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["total"], 0)
        self.assertEqual(len(data["items"]), 0)

    async def test_borrower_loans_status_filter(self) -> None:
        suffix = secrets.token_hex(4)
        bor_id = f"bor-flt-{suffix}"
        acct_id = f"acct-flt-{suffix}"
        user_id = f"usr-flt-{suffix}"
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
                first_name="Filter",
                last_name="Test",
                national_id=f"PH-FLT-{suffix}",
                phone=f"0922{suffix[:7]}",
                date_of_birth=date(1991, 3, 3),
                status="Active",
            )
            db.add(borrower)

            account = BorrowerAccount(
                id=acct_id,
                borrower_id=bor_id,
                phone_number=f"0922{suffix[:7]}",
                phone_number_normalized=f"+63922{suffix[:7]}",
                account_status="active",
            )
            db.add(account)

            active_loan = Loan(
                id=f"loan-act-{suffix}",
                request_id=f"req-act-{suffix}",
                borrower_id=bor_id,
                created_by_user_id=user_id,
                original_principal=5000,
                outstanding_principal=5000,
                monthly_rate=0.03,
                term_months=6,
                payments_per_month=1,
                number_of_payments=6,
                regular_payment_amount=900,
                status="Active",
                calculation_method="fixed_periodic_reducing_balance",
                start_date=today,
                first_due_date=today + timedelta(days=30),
                final_due_date=today + timedelta(days=180),
            )
            db.add(active_loan)

            paid_loan = Loan(
                id=f"loan-paid-{suffix}",
                request_id=f"req-paid-{suffix}",
                borrower_id=bor_id,
                created_by_user_id=user_id,
                original_principal=3000,
                outstanding_principal=0,
                monthly_rate=0.03,
                term_months=3,
                payments_per_month=1,
                number_of_payments=3,
                regular_payment_amount=1050,
                status="Paid",
                calculation_method="fixed_periodic_reducing_balance",
                start_date=today - timedelta(days=120),
                first_due_date=today - timedelta(days=90),
                final_due_date=today - timedelta(days=30),
            )
            db.add(paid_loan)
            await db.commit()

        token = create_borrower_access_token(account)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            # Filter active
            res_active = await client.get(
                "/api/v1/client/loans?status=active",
                headers={"Authorization": f"Bearer {token}"},
            )
            # Filter paid
            res_paid = await client.get(
                "/api/v1/client/loans?status=paid",
                headers={"Authorization": f"Bearer {token}"},
            )

        self.assertEqual(res_active.status_code, 200)
        self.assertEqual(res_active.json()["total"], 1)
        self.assertEqual(res_active.json()["items"][0]["status"], "active")

        self.assertEqual(res_paid.status_code, 200)
        self.assertEqual(res_paid.json()["total"], 1)
        self.assertEqual(res_paid.json()["items"][0]["status"], "paid")

    async def test_borrower_loans_invalid_status_filter(self) -> None:
        suffix = secrets.token_hex(4)
        bor_id = f"bor-inv-{suffix}"
        acct_id = f"acct-inv-{suffix}"

        async with self.session_factory() as db:
            borrower = Borrower(
                id=bor_id,
                first_name="Invalid",
                last_name="Status",
                national_id=f"PH-INV-{suffix}",
                phone=f"0923{suffix[:7]}",
                date_of_birth=date(1994, 4, 4),
                status="Active",
            )
            db.add(borrower)

            account = BorrowerAccount(
                id=acct_id,
                borrower_id=bor_id,
                phone_number=f"0923{suffix[:7]}",
                phone_number_normalized=f"+63923{suffix[:7]}",
                account_status="active",
            )
            db.add(account)
            await db.commit()

        token = create_borrower_access_token(account)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get(
                "/api/v1/client/loans?status=nonexistent_status",
                headers={"Authorization": f"Bearer {token}"},
            )

        self.assertEqual(response.status_code, 422)

    async def test_borrower_loan_detail_success(self) -> None:
        suffix = secrets.token_hex(4)
        bor_id = f"bor-dtl-{suffix}"
        acct_id = f"acct-dtl-{suffix}"
        loan_id = f"loan-dtl-{suffix}"
        user_id = f"usr-dtl-{suffix}"
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
                first_name="Detail",
                last_name="Test",
                national_id=f"PH-DTL-{suffix}",
                phone=f"0924{suffix[:7]}",
                date_of_birth=date(1989, 5, 5),
                status="Active",
            )
            db.add(borrower)

            account = BorrowerAccount(
                id=acct_id,
                borrower_id=bor_id,
                phone_number=f"0924{suffix[:7]}",
                phone_number_normalized=f"+63924{suffix[:7]}",
                account_status="active",
            )
            db.add(account)

            loan = Loan(
                id=loan_id,
                request_id=f"req-dtl-{suffix}",
                borrower_id=bor_id,
                created_by_user_id=user_id,
                original_principal=8000,
                outstanding_principal=8000,
                monthly_rate=0.03,
                term_months=12,
                payments_per_month=1,
                number_of_payments=12,
                regular_payment_amount=700,
                status="Active",
                calculation_method="fixed_periodic_reducing_balance",
                start_date=today,
                first_due_date=today + timedelta(days=30),
                final_due_date=today + timedelta(days=360),
            )
            db.add(loan)

            inst = Installment(
                id=f"inst-dtl-{suffix}",
                loan_id=loan_id,
                installment_number=1,
                due_date=today + timedelta(days=30),
                expected_payment=700,
                expected_interest=200,
                expected_principal=500,
                expected_remaining_principal=7500,
                paid_amount=0,
                status="Scheduled",
            )
            db.add(inst)
            await db.commit()

        token = create_borrower_access_token(account)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get(
                f"/api/v1/client/loans/{loan_id}",
                headers={"Authorization": f"Bearer {token}"},
            )

        self.assertEqual(response.status_code, 200)
        data = response.json()

        self.assertEqual(data["id"], loan_id)
        self.assertEqual(data["status"], "active")
        self.assertIn("financialSummary", data)
        self.assertIn("terms", data)
        self.assertIn("nextInstallment", data)

        fin = data["financialSummary"]
        self.assertEqual(float(fin["principalAmount"]), 8000.0)
        self.assertEqual(float(fin["outstandingBalance"]), 8000.0)

        terms = data["terms"]
        self.assertEqual(terms["installmentCount"], 12)
        self.assertEqual(float(terms["installmentAmount"]), 700.0)
        self.assertEqual(terms["paymentFrequency"], "monthly")

        next_inst = data["nextInstallment"]
        self.assertIsNotNone(next_inst)
        self.assertEqual(next_inst["installmentNumber"], 1)
        self.assertEqual(float(next_inst["amountDue"]), 700.0)

    async def test_borrower_loan_detail_other_borrower_404(self) -> None:
        """Borrower B requesting Borrower A's loan gets 404 Not Found."""
        suffix_a = secrets.token_hex(4)
        suffix_b = secrets.token_hex(4)

        async with self.session_factory() as db:
            officer = User(
                id=f"usr-iso-{suffix_a}",
                username=f"officer_{suffix_a}",
                hashed_password="hash",
                role="officer",
            )
            db.add(officer)

            # Borrower A & Loan A
            bor_a = Borrower(
                id=f"bor-a-{suffix_a}",
                first_name="Borrower",
                last_name="A",
                national_id=f"PH-A-{suffix_a}",
                phone=f"0925{suffix_a[:7]}",
                date_of_birth=date(1990, 1, 1),
                status="Active",
            )
            db.add(bor_a)

            acct_a = BorrowerAccount(
                id=f"acct-a-{suffix_a}",
                borrower_id=bor_a.id,
                phone_number=f"0925{suffix_a[:7]}",
                phone_number_normalized=f"+63925{suffix_a[:7]}",
                account_status="active",
            )
            db.add(acct_a)

            loan_a = Loan(
                id=f"loan-a-{suffix_a}",
                request_id=f"req-a-{suffix_a}",
                borrower_id=bor_a.id,
                created_by_user_id=officer.id,
                original_principal=10000,
                outstanding_principal=10000,
                monthly_rate=0.03,
                term_months=12,
                payments_per_month=1,
                number_of_payments=12,
                regular_payment_amount=850,
                status="Active",
                calculation_method="fixed_periodic_reducing_balance",
                start_date=date.today(),
                first_due_date=date.today() + timedelta(days=30),
                final_due_date=date.today() + timedelta(days=360),
            )
            db.add(loan_a)

            # Borrower B
            bor_b = Borrower(
                id=f"bor-b-{suffix_b}",
                first_name="Borrower",
                last_name="B",
                national_id=f"PH-B-{suffix_b}",
                phone=f"0926{suffix_b[:7]}",
                date_of_birth=date(1992, 2, 2),
                status="Active",
            )
            db.add(bor_b)

            acct_b = BorrowerAccount(
                id=f"acct-b-{suffix_b}",
                borrower_id=bor_b.id,
                phone_number=f"0926{suffix_b[:7]}",
                phone_number_normalized=f"+63926{suffix_b[:7]}",
                account_status="active",
            )
            db.add(acct_b)
            await db.commit()

        token_b = create_borrower_access_token(acct_b)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get(
                f"/api/v1/client/loans/{loan_a.id}",
                headers={"Authorization": f"Bearer {token_b}"},
            )

        self.assertEqual(response.status_code, 404)

    async def test_unauthenticated_loans_rejected(self) -> None:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            res_list = await client.get("/api/v1/client/loans")
            res_dtl = await client.get("/api/v1/client/loans/loan-123")

        self.assertEqual(res_list.status_code, 401)
        self.assertEqual(res_dtl.status_code, 401)

    async def test_officer_token_rejected_on_loans(self) -> None:
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
            res_list = await client.get(
                "/api/v1/client/loans",
                headers={"Authorization": f"Bearer {officer_token}"},
            )
            res_dtl = await client.get(
                "/api/v1/client/loans/loan-123",
                headers={"Authorization": f"Bearer {officer_token}"},
            )

        self.assertEqual(res_list.status_code, 401)
        self.assertEqual(res_dtl.status_code, 401)

    async def test_openapi_schema_contains_borrower_loans(self) -> None:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get("/openapi.json")

        self.assertEqual(response.status_code, 200)
        paths = response.json().get("paths", {})
        self.assertIn("/api/v1/client/loans", paths)
        self.assertIn("/api/v1/client/loans/{loan_id}", paths)
