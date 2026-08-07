"""Tests for non-persistent loan quote calculations."""

import unittest
from datetime import date
from decimal import Decimal

from app.features.loans.schemas import LoanQuoteRequest
from app.features.loans.service import build_quote


class LoanQuoteTests(unittest.TestCase):
    """Verify quote totals use the production amortization engine."""

    def test_quote_returns_totals_dates_and_schedule(self) -> None:
        quote = build_quote(
            LoanQuoteRequest(
                original_principal="1000.00",
                monthly_rate="0.05",
                term_months=10,
                payments_per_month=1,
                first_due_date=date(2026, 8, 1),
            )
        )

        self.assertEqual(quote.regular_payment_amount, Decimal("129.50"))
        self.assertEqual(quote.total_interest, Decimal("295.07"))
        self.assertEqual(quote.total_repayment, Decimal("1295.07"))
        self.assertEqual(quote.final_due_date, date(2027, 5, 1))
        self.assertEqual(len(quote.installments), 10)
        self.assertEqual(quote.installments[-1].remaining_principal, Decimal("0.00"))

    def test_interest_only_quote_calculates_interim_interest_and_bullet_final_repayment(
        self,
    ) -> None:
        quote = build_quote(
            LoanQuoteRequest(
                original_principal="1000.00",
                monthly_rate="0.05",
                term_months=3,
                payments_per_month=1,
                first_due_date=date(2026, 8, 1),
                repayment_structure="interest_only",
            )
        )

        self.assertEqual(quote.repayment_structure, "interest_only")
        self.assertEqual(quote.regular_payment_amount, Decimal("50.00"))
        self.assertEqual(quote.total_interest, Decimal("150.00"))
        self.assertEqual(quote.total_repayment, Decimal("1150.00"))
        self.assertEqual(len(quote.installments), 3)

        # Interim installment 1
        self.assertEqual(quote.installments[0].payment_amount, Decimal("50.00"))
        self.assertEqual(quote.installments[0].interest_amount, Decimal("50.00"))
        self.assertEqual(quote.installments[0].principal_amount, Decimal("0.00"))
        self.assertEqual(
            quote.installments[0].remaining_principal, Decimal("1000.00")
        )

        # Final bullet installment 3
        self.assertEqual(quote.installments[2].payment_amount, Decimal("1050.00"))
        self.assertEqual(quote.installments[2].interest_amount, Decimal("50.00"))
        self.assertEqual(quote.installments[2].principal_amount, Decimal("1000.00"))
        self.assertEqual(
            quote.installments[2].remaining_principal, Decimal("0.00")
        )


if __name__ == "__main__":
    unittest.main()
