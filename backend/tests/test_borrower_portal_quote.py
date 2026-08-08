"""Tests for the borrower loan estimate / quote endpoint.

Group A: Pure Pydantic validation tests (no database).
Group B: FastAPI endpoint tests using mocked DB dependency.
Group C: Integration tests using real PostgreSQL (skipped without DB env var).
"""

import unittest
from datetime import date
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

from httpx import ASGITransport, AsyncClient

from app.features.borrower_portal.schemas import (
    BorrowerLoanQuoteRequest,
)
from app.features.borrower_portal.service import create_borrower_access_token
from app.features.loans.schemas import LoanQuoteRequest
from app.features.loans.service import build_quote
from app.main import app

# ---------------------------------------------------------------------------
# Group A: Pydantic validation (pure unit tests, no DB)
# ---------------------------------------------------------------------------


class TestBorrowerLoanQuoteRequestValidation(unittest.TestCase):
    """BorrowerLoanQuoteRequest Pydantic validation rules."""

    def _valid(self, **overrides):
        defaults = dict(
            requestedAmount="10000.00",
            requestedTermMonths=1,
            requestedPaymentFrequency="monthly",
            requestedRepaymentStructure="principal_plus_interest",
        )
        defaults.update(overrides)
        return BorrowerLoanQuoteRequest(**defaults)

    def test_valid_monthly_principal_plus_interest(self) -> None:
        req = self._valid()
        self.assertEqual(req.requested_amount, "10000.00")

    def test_valid_twice_a_month(self) -> None:
        req = self._valid(requestedPaymentFrequency="twice_a_month")
        self.assertEqual(req.requested_payment_frequency, "twice_a_month")

    def test_rejects_interest_only(self) -> None:
        from pydantic import ValidationError

        with self.assertRaises(ValidationError):
            self._valid(requestedRepaymentStructure="interest_only")

    def test_valid_term_boundaries(self) -> None:
        for term in [1, 2, 3, 6, 12, 120]:
            req = self._valid(requestedTermMonths=term)
            self.assertEqual(req.requested_term_months, term)

    def test_rejects_weekly_frequency(self) -> None:
        from pydantic import ValidationError

        with self.assertRaises(ValidationError):
            self._valid(requestedPaymentFrequency="weekly")

    def test_rejects_invalid_repayment_structure(self) -> None:
        from pydantic import ValidationError

        with self.assertRaises(ValidationError):
            self._valid(requestedRepaymentStructure="balloon")

    def test_rejects_term_zero(self) -> None:
        from pydantic import ValidationError

        with self.assertRaises(ValidationError):
            self._valid(requestedTermMonths=0)

    def test_rejects_term_above_120(self) -> None:
        from pydantic import ValidationError

        with self.assertRaises(ValidationError):
            self._valid(requestedTermMonths=121)

    def test_no_interest_rate_field_accepted(self) -> None:
        """BorrowerLoanQuoteRequest must not accept an interest rate from client."""
        from app.features.borrower_portal.schemas import BorrowerLoanQuoteRequest

        fields = BorrowerLoanQuoteRequest.model_fields
        for forbidden in ("monthly_rate", "interest_rate", "rate"):
            self.assertNotIn(
                forbidden,
                fields,
                f"Field {forbidden!r} must not be on BorrowerLoanQuoteRequest",
            )


# ---------------------------------------------------------------------------
# Group B: FastAPI endpoint tests (mocked DB dependency)
# ---------------------------------------------------------------------------


def _make_borrower_token() -> str:
    account = SimpleNamespace(id="test-acct-001", borrower_id="test-bor-001")
    return create_borrower_access_token(account)


def _make_mock_session(estimate_rate=None):
    """Return a mock AsyncSession whose .get() returns a BusinessSetting mock."""
    from app.features.business_settings.models import BusinessSetting

    settings_mock = MagicMock(spec=BusinessSetting)
    settings_mock.default_monthly_estimate_rate = estimate_rate

    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None

    db = AsyncMock()
    db.get = AsyncMock(return_value=settings_mock)
    db.execute = AsyncMock(return_value=mock_result)
    return db


def _make_active_account():
    """Return a minimal ActiveBorrowerAccount-compatible namespace."""
    account = SimpleNamespace(id="test-acct-001", borrower_id="test-bor-001")
    return account


class TestBorrowerLoanQuoteEndpointMocked(unittest.IsolatedAsyncioTestCase):
    """FastAPI /api/v1/client/loan-requests/quote endpoint tests with mocked DB."""

    TOKEN = _make_borrower_token()

    async def _post_quote(self, payload: dict, session_mock):
        from app.core.database import get_db
        from app.features.borrower_portal.dependencies import (
            require_active_borrower_account,
        )

        async def override_db():
            yield session_mock

        def override_account():
            return _make_active_account()

        app.dependency_overrides[get_db] = override_db
        app.dependency_overrides[require_active_borrower_account] = override_account
        try:
            async with AsyncClient(
                transport=ASGITransport(app=app), base_url="http://test"
            ) as client:
                resp = await client.post(
                    "/api/v1/client/loan-requests/quote",
                    json=payload,
                    headers={"Authorization": f"Bearer {self.TOKEN}"},
                )
        finally:
            app.dependency_overrides.pop(get_db, None)
            app.dependency_overrides.pop(require_active_borrower_account, None)
        return resp

    # 1. No configured rate → available=false
    async def test_no_rate_configured_returns_unavailable(self) -> None:
        db = _make_mock_session(estimate_rate=None)
        resp = await self._post_quote(
            {"requestedAmount": "10000.00", "requestedTermMonths": 1,
             "requestedPaymentFrequency": "monthly",
             "requestedRepaymentStructure": "principal_plus_interest"},
            db,
        )
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertFalse(body["available"])
        self.assertIn("unavailable", body["message"].lower())

    # 2. Configured rate → available=true with estimatedMonthlyRate
    async def test_configured_rate_returns_available(self) -> None:
        db = _make_mock_session(estimate_rate=Decimal("0.10000000"))
        resp = await self._post_quote(
            {"requestedAmount": "10000.00", "requestedTermMonths": 1,
             "requestedPaymentFrequency": "monthly",
             "requestedRepaymentStructure": "principal_plus_interest"},
            db,
        )
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertTrue(body["available"])
        self.assertEqual(body["estimatedMonthlyRate"], "0.10000000")

    # 3. Monthly → 1 payment/month → numberOfPayments == termMonths
    async def test_monthly_frequency_produces_correct_payment_count(self) -> None:
        db = _make_mock_session(estimate_rate=Decimal("0.10000000"))
        resp = await self._post_quote(
            {"requestedAmount": "10000.00", "requestedTermMonths": 3,
             "requestedPaymentFrequency": "monthly",
             "requestedRepaymentStructure": "principal_plus_interest"},
            db,
        )
        body = resp.json()
        self.assertEqual(body["numberOfPayments"], 3)
        self.assertEqual(len(body["installments"]), 3)

    # 4. Twice a month → 2 payments/month → numberOfPayments == termMonths * 2
    async def test_twice_a_month_produces_double_payment_count(self) -> None:
        db = _make_mock_session(estimate_rate=Decimal("0.10000000"))
        resp = await self._post_quote(
            {"requestedAmount": "10000.00", "requestedTermMonths": 1,
             "requestedPaymentFrequency": "twice_a_month",
             "requestedRepaymentStructure": "principal_plus_interest"},
            db,
        )
        body = resp.json()
        self.assertEqual(body["numberOfPayments"], 2)
        self.assertEqual(len(body["installments"]), 2)

    # 5. Principal + Interest — final installment clears remaining principal
    async def test_principal_plus_interest_clears_remaining_principal(self) -> None:
        db = _make_mock_session(estimate_rate=Decimal("0.10000000"))
        resp = await self._post_quote(
            {"requestedAmount": "10000.00", "requestedTermMonths": 1,
             "requestedPaymentFrequency": "monthly",
             "requestedRepaymentStructure": "principal_plus_interest"},
            db,
        )
        body = resp.json()
        last = body["installments"][-1]
        self.assertEqual(Decimal(last["remainingPrincipal"]), Decimal("0.00"))

    # 6. Interest Only — rejected with 422
    async def test_interest_only_rejected_with_422(self) -> None:
        db = _make_mock_session(estimate_rate=Decimal("0.10000000"))
        resp = await self._post_quote(
            {"requestedAmount": "10000.00", "requestedTermMonths": 2,
             "requestedPaymentFrequency": "monthly",
             "requestedRepaymentStructure": "interest_only"},
            db,
        )
        self.assertEqual(resp.status_code, 422)

    # 8. Weekly frequency rejected with 422
    async def test_weekly_frequency_rejected(self) -> None:
        db = _make_mock_session(estimate_rate=Decimal("0.10000000"))
        resp = await self._post_quote(
            {"requestedAmount": "10000.00", "requestedTermMonths": 1,
             "requestedPaymentFrequency": "weekly",
             "requestedRepaymentStructure": "principal_plus_interest"},
            db,
        )
        self.assertEqual(resp.status_code, 422)

    # 9. Invalid repayment structure rejected with 422
    async def test_invalid_repayment_structure_rejected(self) -> None:
        db = _make_mock_session(estimate_rate=Decimal("0.10000000"))
        resp = await self._post_quote(
            {"requestedAmount": "10000.00", "requestedTermMonths": 1,
             "requestedPaymentFrequency": "monthly",
             "requestedRepaymentStructure": "balloon"},
            db,
        )
        self.assertEqual(resp.status_code, 422)

    # 10. Unauthenticated request rejected with 401
    async def test_unauthenticated_request_rejected(self) -> None:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            resp = await client.post(
                "/api/v1/client/loan-requests/quote",
                json={"requestedAmount": "10000.00", "requestedTermMonths": 1,
                      "requestedPaymentFrequency": "monthly",
                      "requestedRepaymentStructure": "principal_plus_interest"},
            )
        self.assertEqual(resp.status_code, 401)

    # 11. Quote creates no Loan record (pure computation)
    async def test_quote_creates_no_loan_record(self) -> None:
        db = _make_mock_session(estimate_rate=Decimal("0.10000000"))
        await self._post_quote(
            {"requestedAmount": "10000.00", "requestedTermMonths": 1,
             "requestedPaymentFrequency": "monthly",
             "requestedRepaymentStructure": "principal_plus_interest"},
            db,
        )
        # Verify no add(Loan(...)) calls were made on the session
        for call in db.add.call_args_list:
            arg = call.args[0] if call.args else None
            from app.features.loans.models import Loan
            self.assertNotIsInstance(arg, Loan, "Quote must not persist a Loan record")

    # 12. Quote creates no Installment record
    async def test_quote_creates_no_installment_record(self) -> None:
        db = _make_mock_session(estimate_rate=Decimal("0.10000000"))
        await self._post_quote(
            {"requestedAmount": "10000.00", "requestedTermMonths": 1,
             "requestedPaymentFrequency": "monthly",
             "requestedRepaymentStructure": "principal_plus_interest"},
            db,
        )
        for call in db.add.call_args_list:
            arg = call.args[0] if call.args else None
            from app.features.loans.models import Installment

            self.assertNotIsInstance(
                arg, Installment, "Quote must not persist Installments"
            )

    # 13. Schedule totalRepayment equals sum of installment payment amounts
    async def test_total_repayment_equals_sum_of_installments(self) -> None:
        db = _make_mock_session(estimate_rate=Decimal("0.10000000"))
        resp = await self._post_quote(
            {"requestedAmount": "10000.00", "requestedTermMonths": 1,
             "requestedPaymentFrequency": "monthly",
             "requestedRepaymentStructure": "principal_plus_interest"},
            db,
        )
        body = resp.json()
        total = Decimal(body["totalRepayment"])
        summed = sum(Decimal(i["paymentAmount"]) for i in body["installments"])
        self.assertEqual(total, summed)

    # 14. Response includes disclaimer
    async def test_response_includes_disclaimer(self) -> None:
        db = _make_mock_session(estimate_rate=Decimal("0.10000000"))
        resp = await self._post_quote(
            {"requestedAmount": "10000.00", "requestedTermMonths": 1,
             "requestedPaymentFrequency": "monthly",
             "requestedRepaymentStructure": "principal_plus_interest"},
            db,
        )
        body = resp.json()
        self.assertIn("disclaimer", body)
        self.assertGreater(len(body["disclaimer"]), 10)

    # 15. Duration variants: 1, 2, 3, 6 months all succeed
    async def test_term_variants_all_return_200(self) -> None:
        for term in [1, 2, 3, 6]:
            with self.subTest(term=term):
                db = _make_mock_session(estimate_rate=Decimal("0.10000000"))
                resp = await self._post_quote(
                    {"requestedAmount": "10000.00", "requestedTermMonths": term,
                     "requestedPaymentFrequency": "monthly",
                     "requestedRepaymentStructure": "principal_plus_interest"},
                    db,
                )
                self.assertEqual(resp.status_code, 200, f"term={term}")
                body = resp.json()
                self.assertEqual(body["numberOfPayments"], term)


# ---------------------------------------------------------------------------
# Group C: Pure build_quote unit tests (no HTTP layer, verifies delegation)
# ---------------------------------------------------------------------------


class TestBuildQuoteDirectly(unittest.TestCase):
    """Confirm build_quote produces financially correct results used by the endpoint."""

    def test_monthly_1month_principal_plus_interest(self) -> None:
        result = build_quote(
            LoanQuoteRequest(
                original_principal="10000.00",
                monthly_rate="0.10",
                term_months=1,
                payments_per_month=1,
                first_due_date=date(2026, 9, 15),
            )
        )
        self.assertEqual(result.number_of_payments, 1)
        self.assertEqual(result.total_repayment, Decimal("11000.00"))
        self.assertEqual(result.installments[0].remaining_principal, Decimal("0.00"))

    def test_twice_a_month_1month_reducing_balance(self) -> None:
        result = build_quote(
            LoanQuoteRequest(
                original_principal="10000.00",
                monthly_rate="0.10",
                term_months=1,
                payments_per_month=2,
                first_due_date=date(2026, 9, 15),
            )
        )
        self.assertEqual(result.number_of_payments, 2)
        self.assertEqual(result.installments[-1].remaining_principal, Decimal("0.00"))

    def test_6month_payment_count(self) -> None:
        result = build_quote(
            LoanQuoteRequest(
                original_principal="10000.00",
                monthly_rate="0.10",
                term_months=6,
                payments_per_month=1,
                first_due_date=date(2026, 9, 15),
            )
        )
        self.assertEqual(result.number_of_payments, 6)

    def test_twice_a_month_6months_payment_count(self) -> None:
        result = build_quote(
            LoanQuoteRequest(
                original_principal="10000.00",
                monthly_rate="0.10",
                term_months=6,
                payments_per_month=2,
                first_due_date=date(2026, 9, 15),
            )
        )
        self.assertEqual(result.number_of_payments, 12)

    def test_total_interest_matches_total_repayment_minus_principal(self) -> None:
        result = build_quote(
            LoanQuoteRequest(
                original_principal="10000.00",
                monthly_rate="0.10",
                term_months=3,
                payments_per_month=1,
                first_due_date=date(2026, 9, 15),
            )
        )
        self.assertEqual(
            result.total_repayment,
            result.original_principal + result.total_interest,
        )
