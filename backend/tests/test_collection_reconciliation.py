"""Cash-custody and reconciliation safety tests."""

import unittest
from datetime import date
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

from pydantic import ValidationError

from app.features.collection.models import CollectionSession
from app.features.collection.router import review_session, submit_session
from app.features.collection.schemas import (
    CollectionSessionDecision,
    CollectionSessionSubmit,
)
from app.features.payments.schemas import PaymentCreate


def _session(*, status: str = "collecting") -> CollectionSession:
    return CollectionSession(
        id="00000000-0000-4000-8000-000000000701",
        collector_user_id="collector-1",
        opened_by_user_id="collector-1",
        opening_cash=Decimal("100.00"),
        expected_cash=Decimal("350.00"),
        actual_cash=Decimal("0.00"),
        cash_variance=Decimal("0.00"),
        deposit_amount=Decimal("0.00"),
        status=status,
    )


class CashPaymentSchemaTests(unittest.TestCase):
    def test_cash_requires_session_and_receipt(self) -> None:
        with self.assertRaises(ValidationError):
            PaymentCreate(
                amount=Decimal("10.00"),
                effective_date=date(2026, 8, 2),
                request_id="00000000-0000-4000-8000-000000000702",
                payment_method="cash",
            )


class CollectionSessionControlTests(unittest.IsolatedAsyncioTestCase):
    async def test_unexplained_variance_cannot_be_submitted(self) -> None:
        db = MagicMock()
        db.scalar = AsyncMock(return_value=_session())
        with self.assertRaises(Exception) as raised:
            await submit_session(
                "session-1",
                CollectionSessionSubmit(actual_cash=Decimal("349.00")),
                db,
                SimpleNamespace(id="collector-1", role="officer"),
            )
        self.assertEqual(raised.exception.status_code, 422)
        db.commit.assert_not_called()

    async def test_collector_cannot_review_own_session(self) -> None:
        db = MagicMock()
        db.scalar = AsyncMock(return_value=_session(status="submitted"))
        with self.assertRaises(Exception) as raised:
            await review_session(
                "session-1",
                CollectionSessionDecision(reason="Counts checked"),
                db,
                SimpleNamespace(id="collector-1", role="admin"),
            )
        self.assertEqual(raised.exception.status_code, 403)

    async def test_checker_can_review_submitted_session(self) -> None:
        session = _session(status="submitted")
        db = MagicMock()
        db.scalar = AsyncMock(return_value=session)
        db.commit = AsyncMock()
        db.refresh = AsyncMock()
        await review_session(
            "session-1",
            CollectionSessionDecision(reason="Cash count verified"),
            db,
            SimpleNamespace(id="manager-1", role="admin"),
        )
        self.assertEqual(session.status, "reviewed")
        self.assertEqual(session.reviewer_user_id, "manager-1")
        db.commit.assert_awaited_once()
