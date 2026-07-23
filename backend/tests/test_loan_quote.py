"""Tests for non-persistent loan quote calculations."""

import unittest
from datetime import date
from decimal import Decimal

from app.schemas.loan import LoanQuoteRequest
from app.services.loan_service import build_quote


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


if __name__ == "__main__":
    unittest.main()
