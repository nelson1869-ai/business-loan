"""Privacy and response-validation tests for loan explanations."""

import json
import unittest
from datetime import date
from decimal import Decimal
from types import SimpleNamespace

import httpx

from app.core.config import Settings
from app.features.admin_assistant.explanation_service import (
    build_safe_loan_context,
    explain_loan,
)


def _loan():
    return SimpleNamespace(
        id="loan-secret-id",
        borrower_id="borrower-secret-id",
        status="Active",
        original_principal=Decimal("1000.00"),
        outstanding_principal=Decimal("800.00"),
        monthly_rate=Decimal("0.10"),
        term_months=5,
        payments_per_month=2,
        number_of_payments=10,
        regular_payment_amount=Decimal("129.50"),
        start_date=date(2026, 8, 1),
        first_due_date=date(2026, 8, 5),
        final_due_date=date(2026, 12, 20),
        installments=[
            SimpleNamespace(
                installment_number=1,
                due_date=date(2026, 8, 5),
                expected_payment=Decimal("129.50"),
                paid_amount=Decimal("0.00"),
                status="Scheduled",
            )
        ],
    )


def _settings() -> Settings:
    return Settings(
        _env_file=None,
        app_env="test",
        database_url="postgresql+asyncpg://user:pass@localhost:5432/db",
        jwt_secret_key="strong-random-value-0123456789-ABCDEFGHIJ",
        cors_origins="https://example.test",
        nvidia_api_key="test-key",
        nvidia_base_url="https://integrate.api.nvidia.test/v1",
    )


class TestAILoanExplanation(unittest.IsolatedAsyncioTestCase):
    def test_context_excludes_identity_fields(self) -> None:
        context = build_safe_loan_context(_loan())
        serialized = json.dumps(context)

        self.assertNotIn("borrower", serialized.lower())
        self.assertNotIn("loan-secret-id", serialized)
        self.assertNotIn("borrower-secret-id", serialized)
        self.assertEqual(context["outstanding_principal"], "800.00")

    async def test_validates_structured_model_response(self) -> None:
        async def handler(request: httpx.Request) -> httpx.Response:
            body = json.loads(request.content)
            prompt = body["messages"][1]["content"]
            self.assertNotIn("borrower-secret-id", prompt)
            self.assertEqual(body["temperature"], 0.2)
            return httpx.Response(
                200,
                json={
                    "choices": [
                        {
                            "message": {
                                "content": json.dumps(
                                    {
                                        "summary": "Ten payments are scheduled.",
                                        "keyPoints": ["The regular payment is 129.50."],
                                    }
                                )
                            }
                        }
                    ]
                },
            )

        result = await explain_loan(
            _loan(),
            _settings(),
            transport=httpx.MockTransport(handler),
        )

        self.assertEqual(result.summary, "Ten payments are scheduled.")
        self.assertEqual(result.model, "openai/gpt-oss-20b")
        self.assertEqual(len(result.key_points), 1)


if __name__ == "__main__":
    unittest.main()
