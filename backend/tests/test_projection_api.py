"""Contracts for backend-owned financial projections and pagination."""

import unittest

from app.features.sync.schemas import SyncQueueItem
from app.main import app


class ProjectionApiContractTests(unittest.TestCase):
    """Verify new read models are authenticated and additive."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.paths = app.openapi()["paths"]

    def test_receipt_and_statement_routes_are_registered(self) -> None:
        receipt = self.paths["/api/v1/payments/{payment_id}/receipt"]["get"]
        statement = self.paths["/api/v1/loans/{loan_id}/statement"]["get"]

        self.assertTrue(receipt["security"])
        self.assertTrue(statement["security"])
        self.assertEqual(
            receipt["responses"]["200"]["content"]["application/json"]["schema"][
                "$ref"
            ],
            "#/components/schemas/ReceiptProjection",
        )
        self.assertEqual(
            statement["responses"]["200"]["content"]["application/json"]["schema"][
                "$ref"
            ],
            "#/components/schemas/LoanStatementProjection",
        )

    def test_dashboard_report_and_pagination_routes_are_registered(self) -> None:
        for path in (
            "/api/v1/dashboard",
            "/api/v1/reports/financial",
            "/api/v1/loans/page",
            "/api/v1/loans/{loan_id}/payments/page",
        ):
            self.assertIn("get", self.paths[path])
            self.assertTrue(self.paths[path]["get"]["security"])

    def test_legacy_collection_contracts_are_unchanged(self) -> None:
        loan_schema = self.paths["/api/v1/loans"]["get"]["responses"]["200"]["content"][
            "application/json"
        ]["schema"]
        payment_schema = self.paths["/api/v1/loans/{loan_id}/payments"]["get"][
            "responses"
        ]["200"]["content"]["application/json"]["schema"]

        self.assertEqual(loan_schema["type"], "array")
        self.assertEqual(payment_schema["type"], "array")


class ExpandedSyncSchemaTests(unittest.TestCase):
    """Ensure offline loan and payment paths pass strict validation."""

    def _item(self, endpoint: str) -> SyncQueueItem:
        return SyncQueueItem.model_validate(
            {
                "transactionUuid": "11111111-1111-4111-8111-111111111111",
                "endpoint": endpoint,
                "method": "POST",
                "payload": {},
                "createdAt": "2026-07-22T00:00:00Z",
            }
        )

    def test_accepts_loan_payment_and_reversal_paths(self) -> None:
        loan_id = "22222222-2222-4222-8222-222222222222"
        payment_id = "33333333-3333-4333-8333-333333333333"

        self.assertEqual(self._item("/api/v1/loans").endpoint, "/api/v1/loans")
        self.assertIn(
            "/payments", self._item(f"/api/v1/loans/{loan_id}/payments").endpoint
        )
        self.assertTrue(
            self._item(
                f"/api/v1/loans/{loan_id}/payments/{payment_id}/reversal"
            ).endpoint.endswith("/reversal")
        )


if __name__ == "__main__":
    unittest.main()
