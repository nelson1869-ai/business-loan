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
                account_status="activated",
            )
            db.add(account)

            loan1 = Loan(
                id=f"loan-1-{suffix}",
                request_id=f"req-1-{suffix}",
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
                account_status="activated",
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
                account_status="activated",
            )
            db.add(account)

            active_loan = Loan(
                id=f"loan-act-{suffix}",
                request_id=f"req-act-{suffix}",
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
                policy_snapshot={"source": "test-fixture"},
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
                account_status="activated",
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
                account_status="activated",
            )
            db.add(account)

            loan = Loan(
                id=loan_id,
                request_id=f"req-dtl-{suffix}",
                borrower_id=bor_id,
                created_by_user_id=user_id,
                policy_snapshot={"source": "test-fixture"},
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
                account_status="activated",
            )
            db.add(acct_a)

            loan_a = Loan(
                id=f"loan-a-{suffix_a}",
                request_id=f"req-a-{suffix_a}",
                borrower_id=bor_a.id,
                created_by_user_id=officer.id,
                policy_snapshot={"source": "test-fixture"},
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
                account_status="activated",
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

    async def test_overdue_installment_prioritized_as_next_payment(self) -> None:
        suffix = secrets.token_hex(4)
        bor_id = f"bor-ovd-{suffix}"
        acct_id = f"acct-ovd-{suffix}"
        user_id = f"usr-ovd-{suffix}"
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
                first_name="Overdue",
                last_name="Priority",
                national_id=f"PH-OVD-{suffix}",
                phone=f"0927{suffix[:7]}",
                date_of_birth=date(1989, 5, 5),
                status="Active",
            )
            db.add(borrower)

            account = BorrowerAccount(
                id=acct_id,
                borrower_id=bor_id,
                phone_number=f"0927{suffix[:7]}",
                phone_number_normalized=f"+63927{suffix[:7]}",
                account_status="activated",
            )
            db.add(account)

            loan = Loan(
                id=f"loan-ovd-{suffix}",
                request_id=f"req-ovd-{suffix}",
                borrower_id=bor_id,
                created_by_user_id=user_id,
                policy_snapshot={"source": "test-fixture"},
                original_principal=10000,
                outstanding_principal=10000,
                monthly_rate=0.03,
                term_months=12,
                payments_per_month=1,
                number_of_payments=12,
                regular_payment_amount=1000,
                status="Overdue",
                calculation_method="fixed_periodic_reducing_balance",
                start_date=today - timedelta(days=40),
                first_due_date=today - timedelta(days=10),
                final_due_date=today + timedelta(days=320),
            )
            db.add(loan)

            # Installment 1: OVERDUE (due 10 days ago)
            inst1 = Installment(
                id=f"inst-ovd-1-{suffix}",
                loan_id=loan.id,
                installment_number=1,
                due_date=today - timedelta(days=10),
                expected_payment=1000,
                expected_interest=250,
                expected_principal=750,
                expected_remaining_principal=9250,
                paid_amount=0,
                status="Overdue",
            )
            # Installment 2: UPCOMING (due in 20 days)
            inst2 = Installment(
                id=f"inst-up-2-{suffix}",
                loan_id=loan.id,
                installment_number=2,
                due_date=today + timedelta(days=20),
                expected_payment=1000,
                expected_interest=250,
                expected_principal=750,
                expected_remaining_principal=8500,
                paid_amount=0,
                status="Scheduled",
            )
            db.add_all([inst1, inst2])
            await db.commit()

        token = create_borrower_access_token(account)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            res_detail = await client.get(
                f"/api/v1/client/loans/{loan.id}",
                headers={"Authorization": f"Bearer {token}"},
            )
            res_dashboard = await client.get(
                "/api/v1/client/dashboard",
                headers={"Authorization": f"Bearer {token}"},
            )

        self.assertEqual(res_detail.status_code, 200)
        dtl = res_detail.json()

        next_inst = dtl["nextInstallment"]
        self.assertIsNotNone(next_inst)
        self.assertEqual(next_inst["installmentNumber"], 1)
        self.assertEqual(next_inst["status"], "overdue")

        dash = res_dashboard.json()
        self.assertEqual(float(dash["summary"]["nextPaymentAmount"]), 1000.0)
        self.assertEqual(
            dash["summary"]["nextDueDate"], str(today - timedelta(days=10))
        )

    async def test_public_loan_reference_safety_excludes_request_id(self) -> None:
        suffix = secrets.token_hex(4)
        bor_id = f"bor-ref-{suffix}"
        acct_id = f"acct-ref-{suffix}"
        user_id = f"usr-ref-{suffix}"
        raw_req_id = "550e8400-e29b-41d4-a716-446655440000"

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
                first_name="Reference",
                last_name="Test",
                national_id=f"PH-REF-{suffix}",
                phone=f"0928{suffix[:7]}",
                date_of_birth=date(1994, 4, 4),
                status="Active",
            )
            db.add(borrower)

            account = BorrowerAccount(
                id=acct_id,
                borrower_id=bor_id,
                phone_number=f"0928{suffix[:7]}",
                phone_number_normalized=f"+63928{suffix[:7]}",
                account_status="activated",
            )
            db.add(account)

            loan = Loan(
                id=f"loan-ref-{suffix}",
                request_id=raw_req_id,
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
                status="Active",
                calculation_method="fixed_periodic_reducing_balance",
                start_date=date.today(),
                first_due_date=date.today() + timedelta(days=30),
                final_due_date=date.today() + timedelta(days=180),
            )
            db.add(loan)
            await db.commit()

        token = create_borrower_access_token(account)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            res_list = await client.get(
                "/api/v1/client/loans",
                headers={"Authorization": f"Bearer {token}"},
            )

        self.assertEqual(res_list.status_code, 200)
        data = res_list.json()
        item = data["items"][0]

        # Verify internal request_id is NEVER exposed as loanReference
        self.assertNotEqual(item["loanReference"], raw_req_id)
        self.assertTrue(item["loanReference"].startswith("LN-"))

    async def test_borrower_loan_schedule_success(self) -> None:
        suffix = secrets.token_hex(4)
        bor_id = f"bor-sch-{suffix}"
        acct_id = f"acct-sch-{suffix}"
        user_id = f"usr-sch-{suffix}"
        loan_id = f"loan-sch-{suffix}"
        today = date.today()

        async with self.session_factory() as db:
            user = User(
                id=user_id,
                username=f"user_sch_{suffix}",
                hashed_password="hash",
                role="officer",
            )
            db.add(user)

            borrower = Borrower(
                id=bor_id,
                first_name="Schedule",
                last_name="Test",
                national_id=f"PH-SCH-{suffix}",
                phone=f"0929{suffix[:7]}",
                date_of_birth=date(1993, 3, 3),
                status="Active",
            )
            db.add(borrower)

            account = BorrowerAccount(
                id=acct_id,
                borrower_id=bor_id,
                phone_number=f"0929{suffix[:7]}",
                phone_number_normalized=f"+63929{suffix[:7]}",
                account_status="activated",
            )
            db.add(account)

            loan = Loan(
                id=loan_id,
                request_id=secrets.token_hex(18),
                borrower_id=bor_id,
                created_by_user_id=user_id,
                policy_snapshot={"source": "test-fixture"},
                original_principal=2000,
                outstanding_principal=2000,
                monthly_rate=0.02,
                term_months=2,
                payments_per_month=1,
                number_of_payments=2,
                regular_payment_amount=1020,
                status="Active",
                calculation_method="fixed_periodic_reducing_balance",
                start_date=today,
                first_due_date=today + timedelta(days=30),
                final_due_date=today + timedelta(days=60),
            )
            db.add(loan)

            inst1 = Installment(
                id=f"inst1-{suffix}",
                loan_id=loan_id,
                installment_number=1,
                due_date=today + timedelta(days=30),
                expected_payment=1020,
                expected_interest=20,
                expected_principal=1000,
                expected_remaining_principal=1000,
                paid_amount=0,
                status="Scheduled",
            )
            inst2 = Installment(
                id=f"inst2-{suffix}",
                loan_id=loan_id,
                installment_number=2,
                due_date=today + timedelta(days=60),
                expected_payment=1020,
                expected_interest=20,
                expected_principal=1000,
                expected_remaining_principal=0,
                paid_amount=0,
                status="Scheduled",
            )
            db.add_all([inst1, inst2])
            await db.commit()

        token = create_borrower_access_token(account)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            res = await client.get(
                f"/api/v1/client/loans/{loan_id}/schedule",
                headers={"Authorization": f"Bearer {token}"},
            )

        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data["loanId"], loan_id)
        self.assertEqual(data["totalInstallments"], 2)
        self.assertEqual(data["paidInstallmentsCount"], 0)
        self.assertEqual(len(data["items"]), 2)
        self.assertEqual(data["items"][0]["installmentNumber"], 1)
        self.assertEqual(data["items"][0]["expectedPayment"], "1020.00")

    async def test_borrower_loan_schedule_unauthorized_other_borrower(self) -> None:
        suffix = secrets.token_hex(4)
        bor_id1 = f"bor1-sch-{suffix}"
        bor_id2 = f"bor2-sch-{suffix}"
        acct_id2 = f"acct2-sch-{suffix}"
        user_id = f"usr2-sch-{suffix}"
        loan_id = f"loan2-sch-{suffix}"

        async with self.session_factory() as db:
            user = User(
                id=user_id,
                username=f"user2_sch_{suffix}",
                hashed_password="hash",
                role="officer",
            )
            db.add(user)

            bor1 = Borrower(
                id=bor_id1,
                first_name="Owner",
                last_name="One",
                national_id=f"PH-O1-{suffix}",
                phone=f"0930{suffix[:7]}",
                date_of_birth=date(1990, 1, 1),
                status="Active",
            )
            bor2 = Borrower(
                id=bor_id2,
                first_name="Attacker",
                last_name="Two",
                national_id=f"PH-O2-{suffix}",
                phone=f"0931{suffix[:7]}",
                date_of_birth=date(1991, 2, 2),
                status="Active",
            )
            db.add_all([bor1, bor2])

            account2 = BorrowerAccount(
                id=acct_id2,
                borrower_id=bor_id2,
                phone_number=f"0931{suffix[:7]}",
                phone_number_normalized=f"+63931{suffix[:7]}",
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
                start_date=date.today(),
                first_due_date=date.today() + timedelta(days=30),
                final_due_date=date.today() + timedelta(days=30),
            )
            db.add(loan)
            await db.commit()

        token2 = create_borrower_access_token(account2)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            res = await client.get(
                f"/api/v1/client/loans/{loan_id}/schedule",
                headers={"Authorization": f"Bearer {token2}"},
            )

        self.assertEqual(res.status_code, 404)

    async def test_submit_borrower_loan_request_persists_requested_terms(self) -> None:
        suffix = secrets.token_hex(4)
        bor_id = f"bor-req-{suffix}"
        acct_id = f"acct-req-{suffix}"

        async with self.session_factory() as db:
            borrower = Borrower(
                id=bor_id,
                first_name="Maria",
                last_name="Santos",
                national_id=f"PH-REQ-{suffix}",
                phone=f"0940{suffix[:7]}",
                date_of_birth=date(1992, 3, 3),
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
            await db.commit()

        token = create_borrower_access_token(account)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            res = await client.post(
                "/api/v1/client/loan-requests",
                headers={"Authorization": f"Bearer {token}"},
                json={
                    "requestedAmount": "5000.00",
                    "requestedTermMonths": 2,
                    "requestedPaymentFrequency": "twice_a_month",
                    "requestedRepaymentStructure": "interest_only",
                    "purpose": "Inventory expansion",
                },
            )

        self.assertEqual(res.status_code, 201)
        data = res.json()
        self.assertEqual(data["requestedAmount"], "5000.00")
        self.assertEqual(data["requestedTermMonths"], 2)
        self.assertEqual(data["requestedPaymentFrequency"], "twice_a_month")
        self.assertEqual(data["requestedRepaymentStructure"], "interest_only")
        self.assertEqual(data["purpose"], "Inventory expansion")
        self.assertEqual(data["status"], "submitted")

    async def test_duplicate_submitted_request_returns_409(self) -> None:
        suffix = secrets.token_hex(4)
        bor_id = f"bor-dup-{suffix}"
        acct_id = f"acct-dup-{suffix}"

        async with self.session_factory() as db:
            borrower = Borrower(
                id=bor_id,
                first_name="Juan",
                last_name="Reyes",
                national_id=f"PH-DUP-{suffix}",
                phone=f"0941{suffix[:7]}",
                date_of_birth=date(1994, 4, 4),
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
            await db.commit()

        token = create_borrower_access_token(account)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            # First submission succeeds
            res1 = await client.post(
                "/api/v1/client/loan-requests",
                headers={"Authorization": f"Bearer {token}"},
                json={
                    "requestedAmount": "3000.00",
                    "requestedTermMonths": 1,
                    "requestedPaymentFrequency": "monthly",
                    "requestedRepaymentStructure": "principal_plus_interest",
                },
            )
            self.assertEqual(res1.status_code, 201)

            # Second submission fails with 409 Conflict
            res2 = await client.post(
                "/api/v1/client/loan-requests",
                headers={"Authorization": f"Bearer {token}"},
                json={
                    "requestedAmount": "4000.00",
                    "requestedTermMonths": 3,
                    "requestedPaymentFrequency": "monthly",
                    "requestedRepaymentStructure": "interest_only",
                },
            )
            self.assertEqual(res2.status_code, 409)
            self.assertIn("awaiting review", res2.json()["detail"])
