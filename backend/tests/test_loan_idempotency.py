"""Unit tests for loan-creation request idempotency."""

import unittest
from datetime import date, datetime, timezone
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from fastapi import HTTPException

from app.features.loans.models import Installment, Loan
from app.features.loans.router import create_one_loan
from app.features.loans.schemas import LoanCreate
from app.features.loans.service import loan_matches_request


class LoanIdempotencyTests(unittest.IsolatedAsyncioTestCase):
    """Verify safe replay and conflicting request-ID reuse."""

    async def test_identical_retry_returns_existing_loan_and_schedule(self) -> None:
        payload = _payload()
        user = SimpleNamespace(id="user-1", role="owner")
        loan = _loan()

        with patch(
            "app.features.loans.router.loan_service.get_loan_by_request_id",
            new=AsyncMock(return_value=loan),
        ):
            response = await create_one_loan(payload, SimpleNamespace(), user)

        self.assertEqual(response.id, loan.id)
        self.assertEqual(response.request_id, payload.request_id)
        self.assertEqual(len(response.installments), 1)

    async def test_changed_terms_reusing_request_id_are_rejected(self) -> None:
        payload = _payload(originalPrincipal="1200.00")
        user = SimpleNamespace(id="user-1", role="owner")

        with patch(
            "app.features.loans.router.loan_service.get_loan_by_request_id",
            new=AsyncMock(return_value=_loan()),
        ):
            with self.assertRaises(HTTPException) as raised:
                await create_one_loan(payload, SimpleNamespace(), user)

        self.assertEqual(raised.exception.status_code, 409)
        self.assertIn("different loan terms", raised.exception.detail)

    def test_term_comparison_includes_officer_and_financial_terms(self) -> None:
        self.assertTrue(loan_matches_request(_loan(), _payload(), "user-1"))
        self.assertFalse(loan_matches_request(_loan(), _payload(), "user-2"))


def _payload(**overrides: object) -> LoanCreate:
    values: dict[str, object] = {
        "borrowerId": "00000000-0000-4000-8000-000000000001",
        "requestId": "00000000-0000-4000-8000-000000000002",
        "originalPrincipal": "1000.00",
        "monthlyRate": "0.10",
        "termMonths": 1,
        "paymentsPerMonth": 1,
        "startDate": "2026-08-01",
        "firstDueDate": "2026-09-01",
    }
    values.update(overrides)
    return LoanCreate.model_validate(values)


def _loan() -> Loan:
    loan = Loan(
        id="loan-1",
        request_id="00000000-0000-4000-8000-000000000002",
        borrower_id="00000000-0000-4000-8000-000000000001",
        created_by_user_id="user-1",
        original_principal=Decimal("1000.00"),
        outstanding_principal=Decimal("1000.00"),
        monthly_rate=Decimal("0.10"),
        term_months=1,
        payments_per_month=1,
        number_of_payments=1,
        regular_payment_amount=Decimal("1100.00"),
        calculation_method="fixed_periodic_reducing_balance",
        start_date=date(2026, 8, 1),
        first_due_date=date(2026, 9, 1),
        final_due_date=date(2026, 9, 1),
        repayment_structure="principal_plus_interest",
        status="Active",
        created_at=datetime(2026, 8, 1, tzinfo=timezone.utc),
    )
    loan.installments = [
        Installment(
            id="installment-1",
            loan_id=loan.id,
            installment_number=1,
            due_date=date(2026, 9, 1),
            expected_payment=Decimal("1100.00"),
            expected_interest=Decimal("100.00"),
            expected_principal=Decimal("1000.00"),
            expected_remaining_principal=Decimal("0.00"),
            paid_amount=Decimal("0.00"),
            status="Scheduled",
            created_at=datetime(2026, 8, 1, tzinfo=timezone.utc),
        )
    ]
    return loan


if __name__ == "__main__":
    unittest.main()
