"""Tests for authoritative payment timing and allocation previews."""

import unittest
from datetime import date
from decimal import Decimal

from pydantic import ValidationError

from app.models.loan import Installment, Loan
from app.models.payment import Payment, PaymentAllocation
from app.schemas.payment import PaymentPreviewRequest, PaymentReversalCreate
from app.services.loan_calculator import LoanCalculationError
from app.services.payment_service import (
    apply_latest_reversal_state,
    build_payment_preview,
    reversal_matches_request,
)


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


class PaymentReversalStateTests(unittest.TestCase):
    """Verify reconstruction restores the immutable before-snapshot."""

    def test_reversal_reopens_paid_loan_and_restores_schedule(self) -> None:
        loan, installment = _loan_and_installment(due_date=date(2026, 8, 31))
        future = Installment(
            id="installment-2",
            loan_id=loan.id,
            installment_number=2,
            due_date=date(2026, 9, 30),
            expected_payment=Decimal("1100.00"),
            expected_interest=Decimal("100.00"),
            expected_principal=Decimal("1000.00"),
            expected_remaining_principal=Decimal("0.00"),
            paid_amount=Decimal("0.00"),
            status="Cancelled",
        )
        loan.installments = [installment, future]
        loan.outstanding_principal = Decimal("0.00")
        loan.status = "Paid"
        installment.paid_amount = Decimal("1100.00")
        installment.status = "Paid"
        original = _payment_with_allocation(
            loan.id,
            installment.id,
            principal_before="1000.00",
            applied_interest="100.00",
            applied_principal="1000.00",
        )

        apply_latest_reversal_state(
            loan,
            installment,
            original,
            date(2026, 8, 31),
        )

        self.assertEqual(loan.outstanding_principal, Decimal("1000.00"))
        self.assertEqual(loan.status, "Active")
        self.assertEqual(installment.paid_amount, Decimal("0.00"))
        self.assertEqual(installment.status, "Scheduled")
        self.assertEqual(future.status, "Scheduled")

    def test_reversal_rejects_inconsistent_paid_amount(self) -> None:
        loan, installment = _loan_and_installment(due_date=date(2026, 8, 31))
        loan.installments = [installment]
        original = _payment_with_allocation(
            loan.id,
            installment.id,
            principal_before="1000.00",
            applied_interest="100.00",
            applied_principal="100.00",
        )

        with self.assertRaisesRegex(LoanCalculationError, "exceeds"):
            apply_latest_reversal_state(
                loan,
                installment,
                original,
                date(2026, 8, 31),
            )

    def test_reversal_requires_uuid_date_and_trimmed_reason(self) -> None:
        request = PaymentReversalCreate.model_validate(
            {
                "requestId": "00000000-0000-4000-8000-000000000099",
                "effectiveDate": "2026-08-17",
                "reason": "  Wrong amount entered  ",
            }
        )

        self.assertEqual(request.reason, "Wrong amount entered")

    def test_reversal_rejects_blank_reason(self) -> None:
        with self.assertRaisesRegex(ValidationError, "non-whitespace"):
            PaymentReversalCreate.model_validate(
                {
                    "requestId": "00000000-0000-4000-8000-000000000099",
                    "effectiveDate": "2026-08-17",
                    "reason": "   ",
                }
            )

    def test_identical_reversal_retry_matches_stored_entry(self) -> None:
        reversal = _payment_with_allocation(
            "loan-1",
            "installment-1",
            principal_before="900.00",
            applied_interest="100.00",
            applied_principal="100.00",
        )
        reversal.request_id = "00000000-0000-4000-8000-000000000099"
        reversal.reversal_of_payment_id = "payment-original"
        reversal.entry_type = "Reversal"
        reversal.effective_date = date(2026, 9, 1)
        reversal.note = "Wrong amount"
        payload = PaymentReversalCreate.model_validate(
            {
                "requestId": reversal.request_id,
                "effectiveDate": "2026-09-01",
                "reason": "Wrong amount",
            }
        )

        self.assertTrue(
            reversal_matches_request(
                reversal,
                "loan-1",
                "payment-original",
                payload,
            )
        )
        self.assertFalse(
            reversal_matches_request(
                reversal,
                "loan-1",
                "different-payment",
                payload,
            )
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


def _payment_with_allocation(
    loan_id: str,
    installment_id: str,
    *,
    principal_before: str,
    applied_interest: str,
    applied_principal: str,
) -> Payment:
    payment = Payment(
        id="payment-1",
        request_id="request-1",
        loan_id=loan_id,
        installment_id=installment_id,
        recorded_by_user_id="user-1",
        entry_type="Payment",
        amount=Decimal(applied_interest) + Decimal(applied_principal),
        effective_date=date(2026, 8, 31),
    )
    payment.allocation = PaymentAllocation(
        id="allocation-1",
        interest_before=Decimal(applied_interest),
        principal_before=Decimal(principal_before),
        applied_interest=Decimal(applied_interest),
        applied_principal=Decimal(applied_principal),
        unapplied_credit=Decimal("0.00"),
        interest_after=Decimal("0.00"),
        principal_after=Decimal(principal_before) - Decimal(applied_principal),
        overdue_days=0,
        scheduled_period_days=30,
    )
    return payment


if __name__ == "__main__":
    unittest.main()
