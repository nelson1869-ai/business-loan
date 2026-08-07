"""Unit and security test suite for Borrower Notifications."""

import json
import unittest
from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

from fastapi import HTTPException

from app.features.notifications.service import (
    ALLOWED_METADATA_KEYS,
    create_borrower_notification,
)
from app.features.payments import receipt_router


class UnitBorrowerNotificationsTests(unittest.IsolatedAsyncioTestCase):
    """Unit tests for borrower notification service and router endpoints."""

    async def test_metadata_scrubbing_and_allowlist(self) -> None:
        """Verify allowed keys are kept and non-allowlisted / sensitive keys are omitted."""
        db = SimpleNamespace(
            execute=AsyncMock(return_value=SimpleNamespace(scalar_one_or_none=lambda: None)),
            add=MagicMock(),
            flush=AsyncMock(),
        )

        n = await create_borrower_notification(
            db,
            borrower_id="borr-123",
            notification_type="payment_receipt",
            title="Receipt",
            message="Payment received",
            entity_type="receipt",
            entity_id="rcpt-1",
            metadata={
                "receipt_id": "rcpt-1",
                "payment_id": "pay-1",
                "pin": "123456",
                "password_hash": "secret",
                "activation_code": "654321",
            },
            deduplication_key="dedup-1",
        )

        self.assertIsNotNone(n.metadata_json)
        parsed = json.loads(n.metadata_json)
        self.assertEqual(parsed.get("entityType"), "receipt")
        self.assertEqual(parsed.get("entityId"), "rcpt-1")
        self.assertEqual(parsed.get("receipt_id"), "rcpt-1")
        self.assertEqual(parsed.get("payment_id"), "pay-1")
        self.assertNotIn("pin", parsed)
        self.assertNotIn("password_hash", parsed)
        self.assertNotIn("activation_code", parsed)

    async def test_deduplication_key_returns_existing(self) -> None:
        """Verify when deduplication_key already exists, the existing notification is returned."""
        existing_notif = SimpleNamespace(id="existing-id", deduplication_key="dedup-key-1")
        db = SimpleNamespace(
            execute=AsyncMock(return_value=SimpleNamespace(scalar_one_or_none=lambda: existing_notif)),
            add=MagicMock(),
            flush=AsyncMock(),
        )

        n = await create_borrower_notification(
            db,
            borrower_id="borr-123",
            notification_type="payment_receipt",
            title="New Title",
            message="New Message",
            deduplication_key="dedup-key-1",
        )

        self.assertEqual(n.id, "existing-id")
        db.add.assert_not_called()

    async def test_mark_notification_read_ownership_check(self) -> None:
        """Verify marking another borrower's notification read raises 404."""
        db = SimpleNamespace(
            execute=AsyncMock(return_value=SimpleNamespace(scalar_one_or_none=lambda: None))
        )
        current_account = SimpleNamespace(borrower_id="borrower-a")

        with self.assertRaises(HTTPException) as ctx:
            await receipt_router.mark_notification_read("notif-of-borrower-b", db, current_account)

        self.assertEqual(ctx.exception.status_code, 404)

    async def test_mark_notification_read_success(self) -> None:
        """Verify owned notification read state is set to True."""
        notif = SimpleNamespace(id="notif-1", borrower_id="borrower-a", is_read=False)
        db = SimpleNamespace(
            execute=AsyncMock(return_value=SimpleNamespace(scalar_one_or_none=lambda: notif)),
            commit=AsyncMock(),
        )
        current_account = SimpleNamespace(borrower_id="borrower-a")

        res = await receipt_router.mark_notification_read("notif-1", db, current_account)
        self.assertTrue(notif.is_read)
        self.assertEqual(res, {"message": "Notification marked as read"})

    async def test_unread_count_query(self) -> None:
        """Verify unread count endpoint executes query and returns count."""
        db = SimpleNamespace(
            execute=AsyncMock(return_value=SimpleNamespace(scalar_one=lambda: 5))
        )
        current_account = SimpleNamespace(borrower_id="borrower-a")

        res = await receipt_router.get_unread_notification_count(db, current_account)
        self.assertEqual(res.unread_count, 5)

    async def test_mark_all_read_query(self) -> None:
        """Verify mark all notifications read executes update query and returns status."""
        db = SimpleNamespace(
            execute=AsyncMock(),
            commit=AsyncMock(),
        )
        current_account = SimpleNamespace(borrower_id="borrower-a")

        res = await receipt_router.mark_all_notifications_read(db, current_account)
        self.assertEqual(res, {"message": "All notifications marked as read"})


if __name__ == "__main__":
    unittest.main()
