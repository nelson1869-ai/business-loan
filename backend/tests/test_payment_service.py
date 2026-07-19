"""Tests for authoritative payment timing and allocation previews."""

import unittest
from datetime import date
from decimal import Decimal

from pydantic import ValidationError

from app.models.loan import Installment, Loan
from app.schemas.payment import PaymentPreviewRequest
from app.services.loan_calculator import LoanCalculationError
from app.services.payment_service import build_payment_preview


class PaymentPreviewScenarioTests(unittest.TestCase):
    """Verify the documented full, partial, early, late, and excess cases."""

    def test_two_hundred_payment_applies_extra_seventy_fifty_to_principal(self) -> None:
        loan, installment = _loan_and_installment(
            payments_per_month=2,
            expected_payment="129.50",
            due_date=date(2026, 8, 16),
        )

        preview = build_payment_preview(
            loan,
            installment,
            Decimal("200.00"),
            date(2026, 8, 16),
            date(2026, 8, 1),
        )

        self.assertEqual(preview.accrued_interest, Decimal("50.00"))
        self.assertEqual(preview.applied_principal, Decimal("150.00"))
        self.assertEqual(preview.amount_above_scheduled, Decimal("70.50"))
        self.assertEqual(preview.principal_after, Decimal("850.00"))
        self.assertEqual(preview.next_period_interest, Decimal("42.50"))

    def test_payment_five_days_late_includes_prorated_interest(self) -> None:
        loan, installment = _loan_and_installment(due_date=date(2026, 8, 31))

        preview = build_payment_preview(
            loan,
            installment,
            Decimal("600.00"),
            date(2026, 9, 5),
            date(2026, 8, 1),
        )

        self.assertEqual(preview.overdue_days, 5)
        self.assertEqual(preview.accrued_interest, Decimal("116.67"))
        self.assertEqual(preview.applied_principal, Decimal("483.33"))
        self.assertEqual(preview.principal_after, Decimal("516.67"))

    def test_full_payoff_on_day_twenty_five_avoids_unaccrued_interest(self) -> None:
        loan, installment = _loan_and_installment(due_date=date(2026, 8, 31))

        preview = build_payment_preview(
            loan,
            installment,
            Decimal("1083.33"),
            date(2026, 8, 26),
            date(2026, 8, 1),
        )

        self.assertEqual(preview.days_early, 5)
        self.assertEqual(preview.accrued_interest, Decimal("83.33"))
        self.assertEqual(preview.applied_principal, Decimal("1000.00"))
        self.assertTrue(preview.is_payoff)

    def test_underpayment_leaves_interest_and_principal(self) -> None:
        loan, installment = _loan_and_installment(due_date=date(2026, 8, 31))

        preview = build_payment_preview(
            loan,
            installment,
            Decimal("60.00"),
            date(2026, 8, 31),
            date(2026, 8, 1),
        )

        self.assertEqual(preview.applied_interest, Decimal("60.00"))
        self.assertEqual(preview.interest_after, Decimal("40.00"))
        self.assertEqual(preview.principal_after, Decimal("1000.00"))

    def test_credit_exists_only_after_interest_and_principal_are_cleared(self) -> None:
        loan, installment = _loan_and_installment(due_date=date(2026, 8, 31))

        preview = build_payment_preview(
            loan,
            installment,
            Decimal("1200.00"),
            date(2026, 8, 31),
            date(2026, 8, 1),
        )

        self.assertEqual(preview.applied_interest, Decimal("100.00"))
        self.assertEqual(preview.applied_principal, Decimal("1000.00"))
        self.assertEqual(preview.unapplied_credit, Decimal("100.00"))
        self.assertTrue(preview.is_payoff)

    def test_second_mid_cycle_payment_accrues_only_since_first_payment(self) -> None:
        loan, installment = _loan_and_installment(due_date=date(2026, 8, 31))

        first = build_payment_preview(
            loan,
            installment,
            Decimal("250.00"),
            date(2026, 8, 16),
            date(2026, 8, 1),
        )
        loan.outstanding_principal = first.principal_after
        second = build_payment_preview(
            loan,
            installment,
            Decimal("169.50"),
            date(2026, 8, 31),
            date(2026, 8, 1),
            accrual_start_date=date(2026, 8, 16),
        )

        self.assertEqual(first.accrued_interest, Decimal("50.00"))
        self.assertEqual(first.applied_principal, Decimal("200.00"))
        self.assertEqual(first.principal_after, Decimal("800.00"))
        self.assertEqual(second.scheduled_period_days, 30)
        self.assertEqual(second.elapsed_days, 15)
        self.assertEqual(second.accrued_interest, Decimal("40.00"))

    def test_payment_before_period_start_is_rejected(self) -> None:
        loan, installment = _loan_and_installment(due_date=date(2026, 8, 31))

        with self.assertRaisesRegex(LoanCalculationError, "period start"):
            build_payment_preview(
                loan,
                installment,
                Decimal("100.00"),
                date(2026, 7, 31),
                date(2026, 8, 1),
            )


class PaymentPreviewSchemaTests(unittest.TestCase):
    """Verify exact JSON financial input at the API boundary."""

    def test_exact_decimal_string_is_accepted(self) -> None:
        request = PaymentPreviewRequest.model_validate(
            {"amount": "200.00", "effectiveDate": "2026-08-16"}
        )

        self.assertEqual(request.amount, Decimal("200.00"))

    def test_binary_float_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValidationError, "exact decimal string"):
            PaymentPreviewRequest.model_validate(
                {"amount": 200.00, "effectiveDate": "2026-08-16"}
            )


def _loan_and_installment(
    *,
    payments_per_month: int = 1,
    expected_payment: str = "1100.00",
    due_date: date,
) -> tuple[Loan, Installment]:
    loan = Loan(
        id="loan-1",
        request_id="request-1",
        borrower_id="borrower-1",
        created_by_user_id="user-1",
        original_principal=Decimal("1000.00"),
        outstanding_principal=Decimal("1000.00"),
        monthly_rate=Decimal("0.10"),
        term_months=1,
        payments_per_month=payments_per_month,
        number_of_payments=payments_per_month,
        regular_payment_amount=Decimal(expected_payment),
        calculation_method="fixed_periodic_reducing_balance",
        start_date=date(2026, 8, 1),
        first_due_date=due_date,
        final_due_date=due_date,
        status="Active",
    )
    installment = Installment(
        id="installment-1",
        loan_id=loan.id,
        installment_number=1,
        due_date=due_date,
        expected_payment=Decimal(expected_payment),
        expected_interest=Decimal("50.00" if payments_per_month == 2 else "100.00"),
        expected_principal=Decimal(expected_payment)
        - Decimal("50.00" if payments_per_month == 2 else "100.00"),
        expected_remaining_principal=Decimal("0.00"),
        paid_amount=Decimal("0.00"),
        status="Scheduled",
    )
    return loan, installment


if __name__ == "__main__":
    unittest.main()
