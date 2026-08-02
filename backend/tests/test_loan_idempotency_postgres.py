"""Opt-in PostgreSQL integration test for concurrent loan retries."""

import asyncio
import os
import unittest
from datetime import date
from uuid import uuid4

from fastapi import HTTPException
from sqlalchemy import func, select

from app.core.database import AsyncSessionFactory, engine
from app.features.borrowers.models import Borrower
from app.features.loans.models import Loan
from app.features.loans.router import create_one_loan
from app.features.loans.schemas import LoanCreate
from app.features.users.models import User


@unittest.skipUnless(
    os.getenv("RUN_POSTGRES_INTEGRATION") == "1",
    "set RUN_POSTGRES_INTEGRATION=1 to use the configured PostgreSQL database",
)
class PostgreSqlLoanIdempotencyTests(unittest.IsolatedAsyncioTestCase):
    """Prove concurrent sessions persist exactly one request-ID row."""

    async def asyncSetUp(self) -> None:
        suffix = uuid4().hex
        phone = f"0917{uuid4().int % 10_000_000:07d}"
        self.user_id = str(uuid4())
        self.borrower_id = str(uuid4())
        self.request_id = str(uuid4())
        async with AsyncSessionFactory() as db:
            db.add(
                User(
                    id=self.user_id,
                    username=f"idempotency-{suffix}",
                    hashed_password="integration-test-only",
                    role="officer",
                )
            )
            db.add(
                Borrower(
                    id=self.borrower_id,
                    first_name="Integration",
                    last_name="Borrower",
                    national_id=f"test-{suffix}",
                    phone=phone,
                    date_of_birth=date(1990, 1, 1),
                    status="Active",
                )
            )
            await db.commit()

    async def asyncTearDown(self) -> None:
        # Posted accounting journals intentionally prevent deleting their actor.
        # This suite runs only against a disposable *_test database.
        await engine.dispose()

    async def test_concurrent_retry_creates_exactly_one_loan(self) -> None:
        payload = self._payload()

        first, second = await asyncio.gather(
            self._submit(payload),
            self._submit(payload),
        )

        self.assertEqual(first.id, second.id)
        async with AsyncSessionFactory() as db:
            count = await db.scalar(
                select(func.count())
                .select_from(Loan)
                .where(Loan.request_id == self.request_id)
            )
        self.assertEqual(count, 1)

        with self.assertRaises(HTTPException) as raised:
            await self._submit(self._payload(originalPrincipal="1200.00"))
        self.assertEqual(raised.exception.status_code, 409)

    async def _submit(self, payload: LoanCreate):
        async with AsyncSessionFactory() as db:
            user = await db.get(User, self.user_id)
            assert user is not None
            return await create_one_loan(payload, db, user)

    def _payload(self, **overrides: object) -> LoanCreate:
        values: dict[str, object] = {
            "borrowerId": self.borrower_id,
            "requestId": self.request_id,
            "originalPrincipal": "1000.00",
            "monthlyRate": "0.10",
            "termMonths": 1,
            "paymentsPerMonth": 1,
            "startDate": "2026-08-01",
            "firstDueDate": "2026-09-01",
        }
        values.update(overrides)
        return LoanCreate.model_validate(values)


if __name__ == "__main__":
    unittest.main()
