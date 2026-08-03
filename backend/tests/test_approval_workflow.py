"""Maker-checker request integrity and authorization tests."""

import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

from app.features.approvals.models import ApprovalRequest
from app.features.approvals.router import REQUEST_PERMISSION
from app.features.approvals.service import (
    consume_approved_request,
    create_request,
    decide_request,
)


def _request(*, status: str = "pending") -> ApprovalRequest:
    return ApprovalRequest(
        id="00000000-0000-4000-8000-000000000801",
        action="payment.reverse",
        entity_type="payment",
        entity_id="payment-1",
        maker_user_id="maker-1",
        status=status,
        request_reason="Incorrect payment amount",
    )


class ApprovalWorkflowTests(unittest.IsolatedAsyncioTestCase):
    def test_maker_permissions_can_submit_controlled_requests(self) -> None:
        self.assertEqual(REQUEST_PERMISSION["loan.approve"], "loan.create")
        self.assertEqual(REQUEST_PERMISSION["payment.reverse"], "payment.collect")

    async def test_creation_records_maker_and_redacted_audit(self) -> None:
        db = MagicMock()
        db.flush = AsyncMock()
        request = await create_request(
            db,
            action="payment.reverse",
            entity_type="payment",
            entity_id="payment-1",
            maker=SimpleNamespace(id="maker-1"),
            reason="Incorrect payment amount",
            before_state={"amount": "100.00"},
            after_state={"economicEffect": "full_reversal"},
        )
        self.assertEqual(request.status, "pending")
        self.assertEqual(request.maker_user_id, "maker-1")
        self.assertNotIn("borrower", request.before_state_json)
        self.assertEqual(db.add.call_count, 2)

    async def test_maker_cannot_decide_own_request(self) -> None:
        db = MagicMock()
        db.scalar = AsyncMock(return_value=_request())
        with self.assertRaisesRegex(PermissionError, "Maker cannot"):
            await decide_request(
                db,
                "request-1",
                SimpleNamespace(id="maker-1"),
                "approved",
                "Reviewed",
            )

    async def test_checker_decision_is_final_and_audited(self) -> None:
        request = _request()
        db = MagicMock()
        db.scalar = AsyncMock(return_value=request)
        db.flush = AsyncMock()
        result = await decide_request(
            db,
            "request-1",
            SimpleNamespace(id="checker-1"),
            "approved",
            "Evidence verified",
        )
        self.assertEqual(result.status, "approved")
        self.assertEqual(result.checker_user_id, "checker-1")
        self.assertIsNotNone(result.decided_at)
        db.flush.assert_awaited_once()

    async def test_final_decision_cannot_be_replayed(self) -> None:
        db = MagicMock()
        db.scalar = AsyncMock(return_value=_request(status="approved"))
        with self.assertRaisesRegex(ValueError, "final decision"):
            await decide_request(
                db,
                "request-1",
                SimpleNamespace(id="checker-2"),
                "rejected",
                "Changed mind",
            )

    async def test_approved_request_is_bound_and_consumed_once(self) -> None:
        request = _request(status="approved")
        request.checker_user_id = "checker-1"
        db = MagicMock()
        db.scalar = AsyncMock(return_value=request)
        db.flush = AsyncMock()
        result = await consume_approved_request(
            db,
            request_id=request.id,
            action="payment.reverse",
            entity_type="payment",
            entity_id="payment-1",
            maker=SimpleNamespace(id="maker-1"),
        )
        self.assertEqual(result.status, "consumed")
        self.assertIsNotNone(result.consumed_at)

    async def test_approval_cannot_be_used_for_another_entity(self) -> None:
        db = MagicMock()
        db.scalar = AsyncMock(return_value=_request(status="approved"))
        with self.assertRaisesRegex(ValueError, "does not match"):
            await consume_approved_request(
                db,
                request_id="request-1",
                action="payment.reverse",
                entity_type="payment",
                entity_id="payment-2",
                maker=SimpleNamespace(id="maker-1"),
            )
