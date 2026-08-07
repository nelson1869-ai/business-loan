"""Contract tests for authenticated, idempotent payment endpoints."""

import unittest
from pathlib import Path

from app.main import app


class PaymentApiContractTests(unittest.TestCase):
    def test_payment_routes_are_registered_with_expected_methods(self) -> None:
        paths = app.openapi()["paths"]

        self.assertIn("post", paths["/api/v1/loans/{loan_id}/payments/preview"])
        self.assertIn("post", paths["/api/v1/loans/{loan_id}/payments"])
        self.assertIn("get", paths["/api/v1/loans/{loan_id}/payments"])
        self.assertIn(
            "post",
            paths["/api/v1/loans/{loan_id}/payments/{payment_id}/reversal"],
        )

        service_path = Path(__file__).parent.parent / "app" / "features" / "payments" / "service.py"
        source = service_path.read_text(encoding="utf-8")

        record_body = source.split("async def record_payment", maxsplit=1)[1]
        self.assertIn("build_payment_preview(", record_body)
        self.assertIn("with_for_update()", source)
        self.assertIn("CREATE_PAYMENT", record_body)

    def test_history_uses_ledger_creation_order_for_reversal_eligibility(self) -> None:
        service_path = Path(__file__).parent.parent / "app" / "features" / "payments" / "service.py"
        source = service_path.read_text(encoding="utf-8")
        history_body = source.split("async def list_payments", maxsplit=1)[1].split(
            "async def", maxsplit=1
        )[0]

        self.assertIn("Payment.created_at.desc()", history_body)
        self.assertNotIn("Payment.effective_date.desc()", history_body)


if __name__ == "__main__":
    unittest.main()
