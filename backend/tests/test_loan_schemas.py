"""Validation tests for loan request and response schemas."""

import unittest
from datetime import date
from decimal import Decimal

from pydantic import ValidationError

from app.features.loans.schemas import LoanCreate


class LoanCreateSchemaTests(unittest.TestCase):
    """Verify exact terms and camel-case API input validation."""

    def _valid_payload(self) -> dict[str, object]:
        return {
            "borrowerId": "00000000-0000-4000-8000-000000000001",
            "requestId": "00000000-0000-4000-8000-000000000002",
            "originalPrincipal": "1000.00",
            "monthlyRate": "0.10",
            "termMonths": 5,
            "paymentsPerMonth": 2,
            "startDate": "2026-08-01",
            "firstDueDate": "2026-08-15",
        }

    def test_camel_case_payload_preserves_exact_decimal_terms(self) -> None:
        loan = LoanCreate.model_validate(self._valid_payload())

        self.assertEqual(loan.original_principal, Decimal("1000.00"))
        self.assertEqual(loan.monthly_rate, Decimal("0.10"))
        self.assertEqual(loan.number_of_payments, 10)
        self.assertEqual(loan.start_date, date(2026, 8, 1))
        self.assertEqual(loan.first_due_date, date(2026, 8, 15))
        self.assertEqual(
            loan.request_id,
            "00000000-0000-4000-8000-000000000002",
        )

    def test_first_due_date_must_follow_start_date(self) -> None:
        payload = self._valid_payload()
        payload["firstDueDate"] = "2026-08-01"

        with self.assertRaisesRegex(ValidationError, "must be after startDate"):
            LoanCreate.model_validate(payload)

    def test_borrower_id_must_be_a_uuid(self) -> None:
        payload = self._valid_payload()
        payload["borrowerId"] = "not-a-valid-borrower-identifier-value"

        with self.assertRaises(ValidationError):
            LoanCreate.model_validate(payload)

    def test_principal_rejects_more_than_two_decimal_places(self) -> None:
        payload = self._valid_payload()
        payload["originalPrincipal"] = "1000.001"

        with self.assertRaises(ValidationError):
            LoanCreate.model_validate(payload)

    def test_binary_float_financial_values_are_rejected(self) -> None:
        payload = self._valid_payload()
        payload["monthlyRate"] = 0.10

        with self.assertRaisesRegex(ValidationError, "exact decimal string"):
            LoanCreate.model_validate(payload)

    def test_zero_or_negative_terms_are_rejected(self) -> None:
        payload = self._valid_payload()
        payload["termMonths"] = 0

        with self.assertRaises(ValidationError):
            LoanCreate.model_validate(payload)


if __name__ == "__main__":
    unittest.main()
