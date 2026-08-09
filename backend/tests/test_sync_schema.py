"""Regression tests for offline sync endpoint validation."""

import unittest
from datetime import UTC, datetime
from uuid import uuid4

from pydantic import ValidationError

from app.features.sync.schemas import SyncQueueItem


class SyncQueueItemSchemaTests(unittest.TestCase):
    def _item(self, endpoint: str, method: str = "POST") -> SyncQueueItem:
        return SyncQueueItem(
            transactionUuid=str(uuid4()),
            endpoint=endpoint,
            method=method,
            payload={},
            createdAt=datetime.now(UTC),
        )

    def test_accepts_supported_extended_offline_routes(self) -> None:
        borrower_id = str(uuid4())
        loan_id = str(uuid4())
        task_id = str(uuid4())
        notification_id = str(uuid4())

        supported = (
            (f"/api/v1/borrowers/{borrower_id}/notes", "POST"),
            (f"/api/v1/borrowers/{borrower_id}/documents", "POST"),
            (
                f"/api/v1/borrowers/{borrower_id}/loans/{loan_id}/notes",
                "POST",
            ),
            (
                f"/api/v1/borrowers/{borrower_id}/loans/{loan_id}/documents",
                "POST",
            ),
            (f"/api/v1/collection-tasks/{task_id}/promise-status", "PATCH"),
            (f"/api/v1/notifications/{notification_id}/read", "PATCH"),
        )

        for endpoint, method in supported:
            with self.subTest(endpoint=endpoint):
                self.assertEqual(self._item(endpoint, method).endpoint, endpoint)

    def test_accepts_business_settings_offline_route(self) -> None:
        """The business-settings PUT enqueued by the settings sheet must be accepted."""
        item = self._item("/api/v1/business-settings", method="PUT")
        self.assertEqual(item.endpoint, "/api/v1/business-settings")
        self.assertEqual(item.method, "PUT")

    def test_rejects_unlisted_or_malformed_routes(self) -> None:
        for endpoint in (
            "/api/v1/users",
            "/api/v1/documents/not-a-uuid",
            "/api/v1/borrowers/../../users",
            "/api/v1/notifications/read-all/extra",
        ):
            with self.subTest(endpoint=endpoint):
                with self.assertRaises(ValidationError):
                    self._item(endpoint)


if __name__ == "__main__":
    unittest.main()
