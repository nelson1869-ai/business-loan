"""Unit tests for exact loan interest and payment allocation."""

import unittest
from decimal import Decimal

from app.features.loans.calculator import (
    LoanCalculationError,
    allocate_payment,
    build_installment_schedule,
    calculate_period_interest,
    calculate_prorated_interest,
)


class InterestCalculationTests(unittest.TestCase):
    """Verify scheduled and prorated interest calculations."""

    def test_ten_percent_of_one_thousand_is_one_hundred(self) -> None:
        interest = calculate_period_interest(Decimal("1000.00"), Decimal("0.10"))

        self.assertEqual(interest, Decimal("100.00"))

    def test_five_days_of_a_thirty_day_period_is_prorated(self) -> None:
        interest = calculate_prorated_interest(
            Decimal("1000.00"),
            Decimal("0.10"),
            elapsed_days=5,
            scheduled_period_days=30,
        )

        self.assertEqual(interest, Decimal("16.67"))


class PaymentAllocationTests(unittest.TestCase):
    """Verify the default interest-first allocation policy."""

    def test_six_hundred_payment_leaves_five_hundred_principal(self) -> None:
        allocation = allocate_payment(
            Decimal("600.00"),
            interest_due=Decimal("100.00"),
            outstanding_principal=Decimal("1000.00"),
        )

        self.assertEqual(allocation.applied_to_interest, Decimal("100.00"))
        self.assertEqual(allocation.applied_to_principal, Decimal("500.00"))
        self.assertEqual(allocation.remaining_interest, Decimal("0.00"))
        self.assertEqual(allocation.remaining_principal, Decimal("500.00"))
        self.assertEqual(allocation.unapplied_credit, Decimal("0.00"))

    def test_underpayment_leaves_interest_due_and_principal_unchanged(self) -> None:
        allocation = allocate_payment(
            Decimal("60.00"),
            interest_due=Decimal("100.00"),
            outstanding_principal=Decimal("1000.00"),
        )

        self.assertEqual(allocation.applied_to_interest, Decimal("60.00"))
        self.assertEqual(allocation.applied_to_principal, Decimal("0.00"))
        self.assertEqual(allocation.remaining_interest, Decimal("40.00"))
        self.assertEqual(allocation.remaining_principal, Decimal("1000.00"))

    def test_overpayment_becomes_unapplied_credit(self) -> None:
        allocation = allocate_payment(
            Decimal("1200.00"),
            interest_due=Decimal("100.00"),
            outstanding_principal=Decimal("1000.00"),
        )

        self.assertEqual(allocation.applied_to_interest, Decimal("100.00"))
        self.assertEqual(allocation.applied_to_principal, Decimal("1000.00"))
        self.assertEqual(allocation.unapplied_credit, Decimal("100.00"))
        self.assertEqual(allocation.remaining_principal, Decimal("0.00"))

    def test_float_inputs_are_rejected(self) -> None:
        with self.assertRaisesRegex(LoanCalculationError, "must be a Decimal"):
            allocate_payment(600.0, Decimal("100.00"), Decimal("1000.00"))  # type: ignore[arg-type]


class InstallmentScheduleTests(unittest.TestCase):
    """Verify regular installments and the final-payment adjustment."""

    def test_ten_payment_schedule_matches_documented_example(self) -> None:
        schedule = build_installment_schedule(
            Decimal("1000.00"),
            periodic_rate=Decimal("0.05"),
            number_of_payments=10,
        )

        self.assertEqual(len(schedule), 10)
        self.assertEqual(schedule[0].payment_amount, Decimal("129.50"))
        self.assertEqual(schedule[0].interest_amount, Decimal("50.00"))
        self.assertEqual(schedule[0].principal_amount, Decimal("79.50"))
        self.assertEqual(schedule[0].remaining_principal, Decimal("920.50"))
        self.assertEqual(schedule[-1].payment_amount, Decimal("129.57"))
        self.assertEqual(schedule[-1].interest_amount, Decimal("6.17"))
        self.assertEqual(schedule[-1].principal_amount, Decimal("123.40"))
        self.assertEqual(schedule[-1].remaining_principal, Decimal("0.00"))
        self.assertEqual(
            sum(item.interest_amount for item in schedule),
            Decimal("295.07"),
        )
        self.assertEqual(
            sum(item.payment_amount for item in schedule),
            Decimal("1295.07"),
        )

    def test_zero_interest_schedule_adjusts_only_the_final_payment(self) -> None:
        schedule = build_installment_schedule(
            Decimal("1000.00"),
            periodic_rate=Decimal("0"),
            number_of_payments=3,
        )

        self.assertEqual(
            [item.payment_amount for item in schedule],
            [Decimal("333.33"), Decimal("333.33"), Decimal("333.34")],
        )
        self.assertEqual(schedule[-1].remaining_principal, Decimal("0.00"))

    def test_payment_count_must_be_positive(self) -> None:
        with self.assertRaisesRegex(LoanCalculationError, "must be positive"):
            build_installment_schedule(Decimal("1000.00"), Decimal("0.05"), 0)


class DocumentedLoanScenarioTests(unittest.TestCase):
    """Lock the roadmap's worked loan examples into executable tests."""

    def test_partial_monthly_payment_reduces_next_interest(self) -> None:
        first_interest = calculate_period_interest(
            Decimal("1000.00"),
            Decimal("0.10"),
        )
        allocation = allocate_payment(
            Decimal("600.00"),
            interest_due=first_interest,
            outstanding_principal=Decimal("1000.00"),
        )
        next_interest = calculate_period_interest(
            allocation.remaining_principal,
            Decimal("0.10"),
        )

        self.assertEqual(first_interest, Decimal("100.00"))
        self.assertEqual(allocation.remaining_principal, Decimal("500.00"))
        self.assertEqual(next_interest, Decimal("50.00"))

    def test_interest_only_payment_leaves_principal_unchanged(self) -> None:
        interest = calculate_period_interest(Decimal("1000.00"), Decimal("0.10"))
        allocation = allocate_payment(
            Decimal("100.00"),
            interest_due=interest,
            outstanding_principal=Decimal("1000.00"),
        )

        self.assertEqual(allocation.applied_to_interest, Decimal("100.00"))
        self.assertEqual(allocation.applied_to_principal, Decimal("0.00"))
        self.assertEqual(allocation.remaining_interest, Decimal("0.00"))
        self.assertEqual(allocation.remaining_principal, Decimal("1000.00"))

    def test_partial_payment_on_day_fifteen_produces_ninety_interest(self) -> None:
        interest_before_payment = calculate_prorated_interest(
            Decimal("1000.00"),
            Decimal("0.10"),
            elapsed_days=15,
            scheduled_period_days=30,
        )
        allocation = allocate_payment(
            Decimal("250.00"),
            interest_due=interest_before_payment,
            outstanding_principal=Decimal("1000.00"),
        )
        interest_after_payment = calculate_prorated_interest(
            allocation.remaining_principal,
            Decimal("0.10"),
            elapsed_days=15,
            scheduled_period_days=30,
        )

        self.assertEqual(interest_before_payment, Decimal("50.00"))
        self.assertEqual(allocation.remaining_principal, Decimal("800.00"))
        self.assertEqual(interest_after_payment, Decimal("40.00"))
        self.assertEqual(
            interest_before_payment + interest_after_payment,
            Decimal("90.00"),
        )

    def test_full_payoff_five_days_early_avoids_unaccrued_interest(self) -> None:
        accrued_interest = calculate_prorated_interest(
            Decimal("1000.00"),
            Decimal("0.10"),
            elapsed_days=25,
            scheduled_period_days=30,
        )
        payoff = allocate_payment(
            Decimal("1083.33"),
            interest_due=accrued_interest,
            outstanding_principal=Decimal("1000.00"),
        )

        self.assertEqual(accrued_interest, Decimal("83.33"))
        self.assertEqual(payoff.remaining_interest, Decimal("0.00"))
        self.assertEqual(payoff.remaining_principal, Decimal("0.00"))
        self.assertEqual(payoff.unapplied_credit, Decimal("0.00"))

    def test_full_payoff_five_days_late_includes_additional_interest(self) -> None:
        scheduled_interest = calculate_period_interest(
            Decimal("1000.00"),
            Decimal("0.10"),
        )
        late_interest = calculate_prorated_interest(
            Decimal("1000.00"),
            Decimal("0.10"),
            elapsed_days=5,
            scheduled_period_days=30,
        )
        total_interest = scheduled_interest + late_interest
        payoff = allocate_payment(
            Decimal("1116.67"),
            interest_due=total_interest,
            outstanding_principal=Decimal("1000.00"),
        )

        self.assertEqual(scheduled_interest, Decimal("100.00"))
        self.assertEqual(late_interest, Decimal("16.67"))
        self.assertEqual(total_interest, Decimal("116.67"))
        self.assertEqual(payoff.remaining_interest, Decimal("0.00"))
        self.assertEqual(payoff.remaining_principal, Decimal("0.00"))
        self.assertEqual(payoff.unapplied_credit, Decimal("0.00"))


if __name__ == "__main__":
    unittest.main()
