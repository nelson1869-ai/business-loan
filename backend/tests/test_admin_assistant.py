"""Security and allowlist tests for the administrative assistant."""

import json
import unittest
from datetime import UTC, datetime
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock, patch

import httpx
from fastapi import HTTPException

from app.config import Settings
from app.routers import admin_assistant
from app.schemas.admin_assistant import (
    AdminAssistantRequest,
    AdminAssistantResponse,
)
from app.services.admin_assistant_service import (
    AnonymousAIPayload,
    BorrowerNotFound,
    UnsupportedAssistantQuestion,
    _enhance_with_ai,
    _operational_records,
    _resolve_borrower,
    answer_admin_question,
    assert_ai_payload_allowlisted,
    business_date,
    classify_question,
    route_question,
    should_use_ai,
)


class AdminAssistantTests(unittest.IsolatedAsyncioTestCase):
    @staticmethod
    def _settings(**overrides) -> Settings:
        values = {
            "_env_file": None,
            "app_env": "test",
            "database_url": "postgresql+asyncpg://user:pass@localhost/db",
            "jwt_secret_key": "strong-random-value-0123456789-ABCDEFGHIJ",
            "cors_origins": "https://example.test",
            "nvidia_api_key": "test-key",
            "nvidia_base_url": "https://nvidia.test/v1",
        }
        values.update(overrides)
        return Settings(**values)

    def test_classifies_approved_business_questions(self) -> None:
        self.assertEqual(classify_question("hello"), "help")
        self.assertEqual(
            classify_question("Who has not paid today?"),
            "unpaid_today",
        )
        self.assertEqual(
            classify_question("How much income was collected this month?"),
            "collections_this_month",
        )
        self.assertEqual(
            classify_question("Summarize portfolio performance"),
            "portfolio_summary",
        )
        self.assertEqual(
            classify_question("Show me the list of borrowers"),
            "borrower_directory",
        )
        self.assertEqual(
            classify_question("How much did they borrow?"),
            "borrower_principal",
        )
        self.assertEqual(
            classify_question("How much does Juan Dela Cruz still owe?"),
            "borrower_balance",
        )
        self.assertEqual(
            classify_question("Show Nelsons overdue installments."),
            "borrower_overdue_installments",
        )
        self.assertEqual(
            classify_question("Summarize this borrower's current loan position."),
            "borrower_loan_summary",
        )

    def test_rejects_arbitrary_query_requests(self) -> None:
        with self.assertRaises(UnsupportedAssistantQuestion):
            classify_question("Run SELECT * FROM users")

    def test_request_accepts_bounded_pagination_offset(self) -> None:
        request = AdminAssistantRequest(
            message="List borrowers",
            offset=50,
        )

        self.assertEqual(request.offset, 50)

    def test_local_router_reports_route_and_confidence(self) -> None:
        match = route_question("How much did they borrow?")

        self.assertEqual(match.intent, "borrower_principal")
        self.assertEqual(match.route, "admin_assistant.borrower_principal")
        self.assertGreaterEqual(match.confidence, 80)

    def test_realistic_english_and_taglish_route_evaluation(self) -> None:
        cases = {
            "Magkano ang nakolekta ngayong buwan?": "collections_this_month",
            "Sino ang hindi nagbayad today?": "unpaid_today",
            "Sino ang due bukas?": "due_tomorrow",
            "Listahan ng borrowers": "borrower_directory",
            "Magkano utang ni Juan Dela Cruz?": "borrower_balance",
            "Kailan susunod na bayad ni Juan Dela Cruz?": "borrower_next_payment",
            "Magkano hiniram ni Juan Dela Cruz?": "borrower_principal",
            "Show payments made by Juan Dela Cruz": "borrower_payment_history",
        }

        for question, expected in cases.items():
            with self.subTest(question=question):
                self.assertEqual(classify_question(question), expected)

    def test_per_admin_rate_limit_rejects_excess_requests(self) -> None:
        admin_assistant._assistant_requests.clear()

        admin_assistant._enforce_rate_limit("admin-1", 2)
        admin_assistant._enforce_rate_limit("admin-1", 2)

        with self.assertRaises(HTTPException) as raised:
            admin_assistant._enforce_rate_limit("admin-1", 2)
        self.assertEqual(raised.exception.status_code, 429)

    @patch("app.services.admin_assistant_service._enhance_with_ai")
    async def test_greeting_is_immediate_and_does_not_call_model(
        self,
        summarize: AsyncMock,
    ) -> None:
        result = await answer_admin_question(
            SimpleNamespace(),
            "hello",
            self._settings(ai_enabled=False),
        )

        self.assertIn("Ask about collections", result.answer)
        summarize.assert_not_awaited()

    def test_ai_payload_is_typed_anonymous_and_allowlisted(self) -> None:
        payload = AnonymousAIPayload(
            intent="borrower_loan_summary",
            currency="PHP",
            loan_status="Active",
            outstanding_balance="12500.00",
            total_paid="7500.00",
            overdue_installments=1,
            next_due_date="2026-08-05",
        )
        serialized = json.dumps(assert_ai_payload_allowlisted(payload)).lower()
        for forbidden in (
            "juan",
            "borrower_id",
            "loan_id",
            "phone",
            "national_id",
            "notes",
            "documents",
            "message",
        ):
            self.assertNotIn(forbidden, serialized)

    def test_simple_factual_intents_never_use_free_tier(self) -> None:
        for intent in (
            "borrower_balance",
            "borrower_next_payment",
            "unpaid_today",
            "collections_this_month",
        ):
            self.assertFalse(should_use_ai(intent, {}))

    def test_business_date_uses_manila_timezone(self) -> None:
        instant = datetime(2026, 7, 28, 16, 30, tzinfo=UTC)
        self.assertEqual(
            business_date(self._settings(ai_enabled=False), instant).isoformat(),
            "2026-07-29",
        )

    async def test_rate_limit_falls_back_without_retry_or_pii(self) -> None:
        calls = 0

        async def handler(request: httpx.Request) -> httpx.Response:
            nonlocal calls
            calls += 1
            body = request.content.decode().lower()
            self.assertNotIn("juan", body)
            self.assertNotIn("borrower_id", body)
            return httpx.Response(429, request=request)

        answer, provider_status = await _enhance_with_ai(
            AnonymousAIPayload(
                intent="portfolio_summary",
                currency="PHP",
                outstanding_balance="1000.00",
                active_loans=2,
                overdue_loans=1,
            ),
            self._settings(),
            transport=httpx.MockTransport(handler),
        )
        self.assertIsNone(answer)
        self.assertEqual(provider_status, "rate_limited")
        self.assertEqual(calls, 1)

    async def test_duplicate_borrower_names_require_clarification(self) -> None:
        borrowers = [
            SimpleNamespace(
                id=f"00000000-0000-4000-8000-00000000000{index}",
                first_name="Juan",
                last_name="Dela Cruz",
                status="Active",
            )
            for index in (1, 2)
        ]
        db = SimpleNamespace(
            execute=AsyncMock(return_value=SimpleNamespace(scalars=lambda: borrowers))
        )

        borrower, clarification = await _resolve_borrower(
            db,
            "How much does Juan Dela Cruz owe?",
            None,
        )

        self.assertIsNone(borrower)
        self.assertEqual(len(clarification.options), 2)

    async def test_pronoun_follow_up_requests_borrower_clarification(self) -> None:
        borrowers = [
            SimpleNamespace(
                id=f"00000000-0000-4000-8000-00000000000{index}",
                first_name=name,
                last_name="Borrower",
                status="Active",
            )
            for index, name in ((1, "Alex"), (2, "Sam"))
        ]
        db = SimpleNamespace(
            execute=AsyncMock(return_value=SimpleNamespace(scalars=lambda: borrowers))
        )

        borrower, clarification = await _resolve_borrower(
            db,
            "How much did they borrow?",
            None,
        )

        self.assertIsNone(borrower)
        self.assertEqual(clarification.message, "Which borrower do you mean?")
        self.assertEqual(len(clarification.options), 2)

    async def test_selected_borrower_is_rechecked_and_missing_is_404(self) -> None:
        db = SimpleNamespace(get=AsyncMock(return_value=None))
        with self.assertRaises(BorrowerNotFound):
            await _resolve_borrower(
                db,
                "borrower balance",
                "00000000-0000-4000-8000-000000000001",
            )
        db.get.assert_awaited_once()

    async def test_full_totals_are_not_limited_to_first_50_records(self) -> None:
        borrower = SimpleNamespace(
            id="borrower",
            first_name="Test",
            last_name="Borrower",
        )
        rows = [
            SimpleNamespace(
                id=f"installment-{index}",
                loan=SimpleNamespace(id=f"loan-{index}", borrower=borrower),
                expected_payment=100,
                paid_amount=0,
                due_date=datetime(2026, 7, 1).date(),
                status="Overdue",
            )
            for index in range(50)
        ]
        db = SimpleNamespace(
            execute=AsyncMock(
                side_effect=[
                    SimpleNamespace(one=lambda: (75, Decimal("7500.00"))),
                    SimpleNamespace(scalars=lambda: rows),
                ]
            )
        )

        records, count, total = await _operational_records(
            db,
            overdue_before=datetime(2026, 7, 28).date(),
        )

        self.assertEqual(count, 75)
        self.assertEqual(total, Decimal("7500.00"))
        self.assertEqual(len(records), 50)

    async def test_non_admin_is_denied_before_query_execution(self) -> None:
        db = SimpleNamespace()
        with self.assertRaises(HTTPException) as raised:
            await admin_assistant.admin_assistant_chat(
                AdminAssistantRequest(message="Who has not paid today?"),
                db,
                SimpleNamespace(id="officer-id", role="officer"),
            )
        self.assertEqual(raised.exception.status_code, 403)

    @patch("app.routers.admin_assistant.answer_admin_question")
    async def test_admin_query_writes_redacted_audit_metadata(
        self,
        answer: AsyncMock,
    ) -> None:
        answer.return_value = AdminAssistantResponse(
            intent="unpaid_today",
            matchedRoute="admin_assistant.unpaid_today",
            intentConfidence=96,
            answer="Two unpaid installments.",
            metrics={"recordCount": 2, "amountDue": "300.00"},
            records=[],
            asOf="2026-07-28",
            generatedAt="2026-07-28T12:00:00Z",
        )
        db = SimpleNamespace(add=Mock(), commit=AsyncMock())
        user_id = "11111111-1111-4111-8111-111111111111"

        await admin_assistant.admin_assistant_chat(
            AdminAssistantRequest(message="Who has not paid today?"),
            db,
            SimpleNamespace(id=user_id, role="admin"),
        )

        audit = db.add.call_args.args[0]
        self.assertEqual(audit.action, "AI_ADMIN_QUERY")
        self.assertNotIn("Who has not paid", audit.new_state_json)
        self.assertIn('"intentConfidence": 96', audit.new_state_json)
        self.assertIn('"matchedRoute": "admin_assistant.unpaid_today"', audit.new_state_json)
        db.commit.assert_awaited_once()


if __name__ == "__main__":
    unittest.main()
