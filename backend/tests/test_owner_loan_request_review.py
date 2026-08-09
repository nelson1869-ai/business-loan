"""Owner loan-request review endpoints against a real database."""

import unittest
from datetime import UTC, datetime, timedelta
from decimal import Decimal

from httpx import ASGITransport, AsyncClient
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.database import get_db
from app.features.auth.service import create_token
from app.features.borrower_portal.models import BorrowerLoanRequest
from app.features.borrowers.models import Borrower
from app.features.loans.models import Loan
from app.features.users.models import User
from app.main import app
from tests.db_test_utils import clean_db_tables, get_verified_test_db_url


class TestOwnerLoanRequestReview(unittest.IsolatedAsyncioTestCase):
    """Owner list + approve/decline of borrower loan requests."""

    async def asyncSetUp(self) -> None:
        db_url = get_verified_test_db_url()
        self.engine = create_async_engine(db_url, echo=False, future=True)
        self.session_factory = async_sessionmaker(
            self.engine, class_=AsyncSession, expire_on_commit=False
        )

        async with self.session_factory() as db:
            await clean_db_tables(db)

        async def _override_get_db():
            async with self.session_factory() as session:
                yield session

        app.dependency_overrides[get_db] = _override_get_db

    async def asyncTearDown(self) -> None:
        app.dependency_overrides.pop(get_db, None)
        await self.engine.dispose()

    async def _seed(self) -> tuple[User, User, Borrower, BorrowerLoanRequest]:
        """Seed owner, officer, borrower, and one submitted loan request."""
        async with self.session_factory() as db:
            owner = User(
                id="usr-lr-owner",
                username="lr_owner",
                hashed_password="hashed",
                role="owner",
            )
            officer = User(
                id="usr-lr-officer",
                username="lr_officer",
                hashed_password="hashed",
                role="officer",
            )
            db.add_all([owner, officer])

            borrower = Borrower(
                id="b0a0a0a0-0000-4000-8000-000000000001",
                first_name="Lorna",
                last_name="Reyes",
                national_id="PH-99887766",
                phone="09175551234",
                phone_normalized="+639175551234",
                date_of_birth=datetime(1991, 6, 20).date(),
                status="Active",
            )
            db.add(borrower)
            await db.flush()

            request = BorrowerLoanRequest(
                id="c0a0a0a0-0000-4000-8000-000000000001",
                borrower_id=borrower.id,
                requested_amount="25000.00",
                requested_term_months=6,
                requested_payment_frequency="monthly",
                requested_repayment_structure="principal_plus_interest",
                purpose="Business restock",
                status="submitted",
                created_at=datetime.now(UTC),
                updated_at=datetime.now(UTC),
            )
            db.add(request)
            await db.commit()
            return owner, officer, borrower, request

    async def test_list_requires_owner_auth(self) -> None:
        await self._seed()
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            resp = await client.get("/api/v1/borrower-loan-requests")
            self.assertEqual(resp.status_code, 401)

    async def test_non_owner_forbidden(self) -> None:
        _, officer, _, _ = await self._seed()
        token = create_token(officer, "access")
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            resp = await client.get(
                "/api/v1/borrower-loan-requests",
                headers={"Authorization": f"Bearer {token}"},
            )
            self.assertEqual(resp.status_code, 403)

    async def test_owner_lists_requests_with_borrower_info(self) -> None:
        owner, _, _, request = await self._seed()
        token = create_token(owner, "access")
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            resp = await client.get(
                "/api/v1/borrower-loan-requests",
                headers={"Authorization": f"Bearer {token}"},
            )
            self.assertEqual(resp.status_code, 200, resp.text)
            items = resp.json()
            self.assertTrue(any(i["id"] == request.id for i in items))
            item = next(i for i in items if i["id"] == request.id)
            self.assertEqual(item["borrowerFullName"], "Lorna Reyes")
            self.assertIn("•••••", item["borrowerPhoneMasked"])
            self.assertEqual(item["requestedAmount"], "25000.00")
            self.assertEqual(item["status"], "submitted")

    async def test_owner_status_filter(self) -> None:
        owner, _, _, request = await self._seed()
        token = create_token(owner, "access")
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            resp = await client.get(
                "/api/v1/borrower-loan-requests?status=approved",
                headers={"Authorization": f"Bearer {token}"},
            )
            self.assertEqual(resp.status_code, 200)
            self.assertNotIn(request.id, [i["id"] for i in resp.json()])

            resp = await client.get(
                "/api/v1/borrower-loan-requests?status=submitted",
                headers={"Authorization": f"Bearer {token}"},
            )
            self.assertEqual(resp.status_code, 200)
            self.assertIn(request.id, [i["id"] for i in resp.json()])

    async def test_owner_approves_loan_request(self) -> None:
        owner, _, _, request = await self._seed()
        token = create_token(owner, "access")
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            resp = await client.post(
                f"/api/v1/borrower-loan-requests/{request.id}/review",
                headers={"Authorization": f"Bearer {token}"},
                json={"action": "approve", "ownerNotes": "Approved by owner"},
            )
            self.assertEqual(resp.status_code, 200, resp.text)
            data = resp.json()
            self.assertEqual(data["status"], "approved")
            self.assertEqual(data["ownerNotes"], "Approved by owner")
            self.assertIsNotNone(data["reviewedAt"])
            self.assertIsNotNone(data["createdDraftLoanId"])

        async with self.session_factory() as db:
            row = await db.get(BorrowerLoanRequest, request.id)
            self.assertEqual(row.status, "approved")
            draft = await db.get(Loan, row.created_draft_loan_id)
            self.assertIsNotNone(draft)
            self.assertEqual(draft.status, "Draft")
            self.assertEqual(draft.borrower_id, row.borrower_id)
            self.assertEqual(draft.original_principal, Decimal("25000.00"))
            self.assertEqual(draft.term_months, 6)
            self.assertEqual(draft.payments_per_month, 1)
            self.assertEqual(draft.repayment_structure, "principal_plus_interest")

    async def test_owner_approves_twice_creates_single_draft(self) -> None:
        owner, _, _, request = await self._seed()
        token = create_token(owner, "access")
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            for _ in range(2):
                resp = await client.post(
                    f"/api/v1/borrower-loan-requests/{request.id}/review",
                    headers={"Authorization": f"Bearer {token}"},
                    json={"action": "approve"},
                )
                self.assertEqual(resp.status_code, 200, resp.text)

        async with self.session_factory() as db:
            row = await db.get(BorrowerLoanRequest, request.id)
            draft = await db.get(Loan, row.created_draft_loan_id)
            self.assertIsNotNone(draft)
            self.assertEqual(draft.status, "Draft")

            from sqlalchemy import func, select

            res = await db.execute(
                select(func.count(Loan.id)).where(Loan.borrower_id == request.borrower_id)
            )
            self.assertEqual(res.scalar_one(), 1)

    async def test_owner_declines_does_not_create_draft(self) -> None:
        owner, _, _, request = await self._seed()
        token = create_token(owner, "access")
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            resp = await client.post(
                f"/api/v1/borrower-loan-requests/{request.id}/review",
                headers={"Authorization": f"Bearer {token}"},
                json={"action": "decline", "ownerNotes": "Terms too high"},
            )
            self.assertEqual(resp.status_code, 200, resp.text)
            self.assertEqual(resp.json()["status"], "declined")

        async with self.session_factory() as db:
            row = await db.get(BorrowerLoanRequest, request.id)
            self.assertEqual(row.status, "declined")
            self.assertIsNone(row.created_draft_loan_id)

            from sqlalchemy import func, select

            res = await db.execute(
                select(func.count(Loan.id)).where(Loan.borrower_id == request.borrower_id)
            )
            self.assertEqual(res.scalar_one(), 0)

    async def test_review_missing_request_returns_404(self) -> None:
        owner, _, _, _ = await self._seed()
        token = create_token(owner, "access")
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            resp = await client.post(
                "/api/v1/borrower-loan-requests/does-not-exist/review",
                headers={"Authorization": f"Bearer {token}"},
                json={"action": "approve"},
            )
            self.assertEqual(resp.status_code, 404, resp.text)

    async def test_review_requires_owner(self) -> None:
        _, officer, _, request = await self._seed()
        token = create_token(officer, "access")
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            resp = await client.post(
                f"/api/v1/borrower-loan-requests/{request.id}/review",
                headers={"Authorization": f"Bearer {token}"},
                json={"action": "approve"},
            )
            self.assertEqual(resp.status_code, 403, resp.text)


if __name__ == "__main__":
    unittest.main()
