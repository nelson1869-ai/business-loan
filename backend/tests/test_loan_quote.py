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

    def test_interest_only_quote_request_is_rejected(self) -> None:
        from pydantic import ValidationError

        with self.assertRaises(ValidationError):
            LoanQuoteRequest(
                original_principal=Decimal("1000.00"),
                monthly_rate=Decimal("0.05"),
                term_months=3,
                payments_per_month=1,
                first_due_date=date(2026, 8, 1),
                repayment_structure="interest_only",  # type: ignore[arg-type]
            )


class CalendarDueDatesTests(unittest.TestCase):
    """Verify exact canonical calendar due date generation."""

    def test_monthly_normal_date(self) -> None:
        quote = build_quote(
            LoanQuoteRequest(
                original_principal="1000.00",
                monthly_rate="0.05",
                term_months=2,
                payments_per_month=1,
                first_due_date=date(2026, 3, 15),
            )
        )
        dates = [inst.due_date for inst in quote.installments]
        self.assertEqual(dates, [date(2026, 3, 15), date(2026, 4, 15)])

    def test_monthly_january_31_month_end_clamping(self) -> None:
        quote = build_quote(
            LoanQuoteRequest(
                original_principal="1000.00",
                monthly_rate="0.05",
                term_months=3,
                payments_per_month=1,
                first_due_date=date(2026, 1, 31),
            )
        )
        dates = [inst.due_date for inst in quote.installments]
        self.assertEqual(
            dates,
            [date(2026, 1, 31), date(2026, 2, 28), date(2026, 3, 31)],
        )

    def test_twice_a_month_starting_15th_march(self) -> None:
        quote = build_quote(
            LoanQuoteRequest(
                original_principal="1000.00",
                monthly_rate="0.05",
                term_months=2,
                payments_per_month=2,
                first_due_date=date(2026, 3, 15),
            )
        )
        dates = [inst.due_date for inst in quote.installments]
        self.assertEqual(
            dates,
            [
                date(2026, 3, 15),
                date(2026, 3, 31),
                date(2026, 4, 15),
                date(2026, 4, 30),
            ],
        )

    def test_twice_a_month_starting_31st_march(self) -> None:
        quote = build_quote(
            LoanQuoteRequest(
                original_principal="1000.00",
                monthly_rate="0.05",
                term_months=2,
                payments_per_month=2,
                first_due_date=date(2026, 3, 31),
            )
        )
        dates = [inst.due_date for inst in quote.installments]
        self.assertEqual(
            dates,
            [
                date(2026, 3, 31),
                date(2026, 4, 15),
                date(2026, 4, 30),
                date(2026, 5, 15),
            ],
        )

    def test_twice_a_month_february_2026_non_leap(self) -> None:
        quote = build_quote(
            LoanQuoteRequest(
                original_principal="1000.00",
                monthly_rate="0.05",
                term_months=1,
                payments_per_month=2,
                first_due_date=date(2026, 2, 15),
            )
        )
        dates = [inst.due_date for inst in quote.installments]
        self.assertEqual(dates, [date(2026, 2, 15), date(2026, 2, 28)])

    def test_twice_a_month_february_2028_leap_year(self) -> None:
        quote = build_quote(
            LoanQuoteRequest(
                original_principal="1000.00",
                monthly_rate="0.05",
                term_months=1,
                payments_per_month=2,
                first_due_date=date(2028, 2, 15),
            )
        )
        dates = [inst.due_date for inst in quote.installments]
        self.assertEqual(dates, [date(2028, 2, 15), date(2028, 2, 29)])

    def test_twice_a_month_year_boundary(self) -> None:
        quote = build_quote(
            LoanQuoteRequest(
                original_principal="1000.00",
                monthly_rate="0.05",
                term_months=2,
                payments_per_month=2,
                first_due_date=date(2026, 12, 15),
            )
        )
        dates = [inst.due_date for inst in quote.installments]
        self.assertEqual(
            dates,
            [
                date(2026, 12, 15),
                date(2026, 12, 31),
                date(2027, 1, 15),
                date(2027, 1, 31),
            ],
        )


if __name__ == "__main__":
    unittest.main()
