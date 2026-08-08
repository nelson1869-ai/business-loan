"""Financial regression tests for Flexible Reducing-Balance Repayment model."""

import unittest
from datetime import date
from decimal import Decimal

from pydantic import ValidationError

from app.features.borrower_portal.schemas import (
    BorrowerLoanQuoteRequest,
    BorrowerLoanRequestSubmit,
)
from app.features.loans.calculator import (
    allocate_payment,
    calculate_period_interest,
)
from app.features.loans.models import Installment, Loan
from app.features.loans.schemas import LoanCreate, LoanQuoteRequest
from app.features.payments.service import build_payment_preview


class FlexibleRepaymentFinancialTests(unittest.TestCase):
    """Verify Section 26 & 27 flexible reducing-balance financial requirements."""

    def test_payment_200_against_2000_principal_200_interest(self) -> None:
        """Requirement 10: Pay ₱200 -> ₱200 interest, ₱0 principal, ₱2,000 remaining principal."""
        allocation = allocate_payment(
            payment_amount=Decimal("200.00"),
            interest_due=Decimal("200.00"),
            outstanding_principal=Decimal("2000.00"),
        )
        self.assertEqual(allocation.applied_to_interest, Decimal("200.00"))
        self.assertEqual(allocation.applied_to_principal, Decimal("0.00"))
        self.assertEqual(allocation.remaining_principal, Decimal("2000.00"))
        self.assertEqual(allocation.remaining_interest, Decimal("0.00"))
        self.assertEqual(allocation.unapplied_credit, Decimal("0.00"))

    def test_payment_700_against_2000_principal_200_interest(self) -> None:
        """Requirement 11: Pay ₱700 -> ₱200 interest, ₱500 principal, ₱1,500 remaining principal."""
        allocation = allocate_payment(
            payment_amount=Decimal("700.00"),
            interest_due=Decimal("200.00"),
            outstanding_principal=Decimal("2000.00"),
        )
        self.assertEqual(allocation.applied_to_interest, Decimal("200.00"))
        self.assertEqual(allocation.applied_to_principal, Decimal("500.00"))
        self.assertEqual(allocation.remaining_principal, Decimal("1500.00"))
        self.assertEqual(allocation.remaining_interest, Decimal("0.00"))
        self.assertEqual(allocation.unapplied_credit, Decimal("0.00"))

    def test_next_period_interest_monthly_10_percent_on_1500(self) -> None:
        """Requirement 12 & 13 & 27: Next monthly interest at 10% on ₱1,500 = ₱150."""
        new_principal = Decimal("1500.00")
        monthly_rate = Decimal("0.10")
        next_interest = calculate_period_interest(new_principal, monthly_rate)
        self.assertEqual(next_interest, Decimal("150.00"))

    def test_next_period_interest_twice_monthly_5_percent_on_1500(self) -> None:
        """Requirement 14: Next twice-monthly periodic interest at 5% on ₱1,500 = ₱75."""
        new_principal = Decimal("1500.00")
        monthly_rate = Decimal("0.10")
        payments_per_month = 2
        periodic_rate = monthly_rate / Decimal(payments_per_month)  # 0.05
        next_interest = calculate_period_interest(new_principal, periodic_rate)
        self.assertEqual(next_interest, Decimal("75.00"))

    def test_partial_interest_payment_leaves_interest_outstanding(self) -> None:
        """Requirement 15: Partial interest payment leaves unpaid interest outstanding."""
        allocation = allocate_payment(
            payment_amount=Decimal("150.00"),
            interest_due=Decimal("200.00"),
            outstanding_principal=Decimal("2000.00"),
        )
        self.assertEqual(allocation.applied_to_interest, Decimal("150.00"))
        self.assertEqual(allocation.applied_to_principal, Decimal("0.00"))
        self.assertEqual(allocation.remaining_interest, Decimal("50.00"))
        self.assertEqual(allocation.remaining_principal, Decimal("2000.00"))

    def test_overpayment_after_interest_reduces_principal(self) -> None:
        """Requirement 16: Overpayment after interest reduces principal."""
        allocation = allocate_payment(
            payment_amount=Decimal("1200.00"),
            interest_due=Decimal("200.00"),
            outstanding_principal=Decimal("2000.00"),
        )
        self.assertEqual(allocation.applied_to_interest, Decimal("200.00"))
        self.assertEqual(allocation.applied_to_principal, Decimal("1000.00"))
        self.assertEqual(allocation.remaining_principal, Decimal("1000.00"))
        self.assertEqual(allocation.unapplied_credit, Decimal("0.00"))

    def test_payment_larger_than_all_obligations_becomes_unapplied_credit(self) -> None:
        """Requirement 17: Payment larger than principal + interest becomes unapplied credit."""
        allocation = allocate_payment(
            payment_amount=Decimal("2500.00"),
            interest_due=Decimal("200.00"),
            outstanding_principal=Decimal("2000.00"),
        )
        self.assertEqual(allocation.applied_to_interest, Decimal("200.00"))
        self.assertEqual(allocation.applied_to_principal, Decimal("2000.00"))
        self.assertEqual(allocation.remaining_principal, Decimal("0.00"))
        self.assertEqual(allocation.unapplied_credit, Decimal("300.00"))

    def test_loan_is_not_paid_while_principal_remains(self) -> None:
        """Requirement 18 & 19: Loan is not paid while principal > 0."""
        loan = Loan(
            id="loan-test-1",
            request_id="req-1",
            borrower_id="bor-1",
            created_by_user_id="user-1",
            original_principal=Decimal("2000.00"),
            outstanding_principal=Decimal("2000.00"),
            monthly_rate=Decimal("0.10"),
            term_months=1,
            payments_per_month=1,
            number_of_payments=1,
            regular_payment_amount=Decimal("2200.00"),
            calculation_method="fixed_periodic_reducing_balance",
            start_date=date(2026, 8, 1),
            first_due_date=date(2026, 9, 1),
            final_due_date=date(2026, 9, 1),
            status="Active",
        )
        installment = Installment(
            id="inst-1",
            loan_id=loan.id,
            installment_number=1,
            due_date=date(2026, 9, 1),
            expected_payment=Decimal("2200.00"),
            expected_interest=Decimal("200.00"),
            expected_principal=Decimal("2000.00"),
            expected_remaining_principal=Decimal("0.00"),
            paid_amount=Decimal("0.00"),
            status="Scheduled",
        )

        preview = build_payment_preview(
            loan,
            installment,
            Decimal("700.00"),
            effective_date=date(2026, 9, 1),
            period_start_date=date(2026, 8, 1),
        )

        self.assertEqual(preview.applied_interest, Decimal("200.00"))
        self.assertEqual(preview.applied_principal, Decimal("500.00"))
        self.assertEqual(preview.principal_after, Decimal("1500.00"))
        self.assertFalse(preview.is_payoff)  # Principal > 0 -> NOT payoff

        # Pay remaining principal + interest
        payoff_preview = build_payment_preview(
            loan,
            installment,
            Decimal("2200.00"),
            effective_date=date(2026, 9, 1),
            period_start_date=date(2026, 8, 1),
        )
        self.assertTrue(payoff_preview.is_payoff)


class NewLoanContractRejectionTests(unittest.TestCase):
    """Verify Section 22 & 25 contract rules for new loans."""

    def test_interest_only_rejected_in_loan_create(self) -> None:
        with self.assertRaises(ValidationError) as ctx:
            LoanCreate(
                borrower_id="00000000-0000-0000-0000-000000000001",
                original_principal=Decimal("2000.00"),
                monthly_rate=Decimal("0.10"),
                term_months=1,
                payments_per_month=1,
                start_date=date(2026, 8, 1),
                first_due_date=date(2026, 9, 1),
                repayment_structure="interest_only",  # type: ignore[arg-type]
            )
        self.assertIn("Interest-only loans are no longer available", str(ctx.exception))

    def test_interest_only_rejected_in_loan_quote_request(self) -> None:
        with self.assertRaises(ValidationError) as ctx:
            LoanQuoteRequest(
                original_principal=Decimal("2000.00"),
                monthly_rate=Decimal("0.10"),
                term_months=1,
                payments_per_month=1,
                first_due_date=date(2026, 9, 1),
                repayment_structure="interest_only",  # type: ignore[arg-type]
            )
        self.assertIn("Interest-only loans are no longer available", str(ctx.exception))

    def test_interest_only_rejected_in_borrower_loan_request_submit(self) -> None:
        with self.assertRaises(ValidationError) as ctx:
            BorrowerLoanRequestSubmit(
                requestedAmount="2000.00",
                requestedTermMonths=1,
                requestedPaymentFrequency="monthly",
                requestedRepaymentStructure="interest_only",  # type: ignore[arg-type]
            )
        self.assertIn("Interest-only loans are no longer available", str(ctx.exception))

    def test_interest_only_rejected_in_borrower_loan_quote_request(self) -> None:
        with self.assertRaises(ValidationError) as ctx:
            BorrowerLoanQuoteRequest(
                requestedAmount="2000.00",
                requestedTermMonths=1,
                requestedPaymentFrequency="monthly",
                requestedRepaymentStructure="interest_only",  # type: ignore[arg-type]
            )
        self.assertIn("Interest-only loans are no longer available", str(ctx.exception))

    def test_weekly_frequency_rejected(self) -> None:
        with self.assertRaises(ValidationError):
            BorrowerLoanRequestSubmit(
                requestedAmount="2000.00",
                requestedTermMonths=1,
                requestedPaymentFrequency="weekly",  # type: ignore[arg-type]
            )


if __name__ == "__main__":
    unittest.main()
