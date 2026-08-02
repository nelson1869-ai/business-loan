"""Historical portfolio reporting formula tests."""

import unittest
from datetime import date, datetime, timezone
from decimal import Decimal

from pydantic import ValidationError

from app.features.business_settings.schemas import BusinessSettingUpdate
from app.features.loans.models import Installment, Loan
from app.features.payments.models import Payment, PaymentAllocation
from app.features.reports.service import historical_loan_position


def _loan() -> Loan:
    loan = Loan(
        id="loan-1",
        request_id="request-1",
        borrower_id="borrower-1",
        created_by_user_id="user-1",
        policy_snapshot={"source": "test"},
        original_principal=Decimal("1000.00"),
        outstanding_principal=Decimal("700.00"),
        monthly_rate=Decimal("0.05"),
        term_months=2,
        payments_per_month=1,
        number_of_payments=2,
        regular_payment_amount=Decimal("550.00"),
        calculation_method="fixed_periodic_reducing_balance",
        start_date=date(2026, 1, 1),
        first_due_date=date(2026, 2, 1),
        final_due_date=date(2026, 3, 1),
        status="Active",
        created_at=datetime(2026, 1, 1, tzinfo=timezone.utc),
    )
    first = Installment(
        id="installment-1",
        loan_id=loan.id,
        installment_number=1,
        due_date=date(2026, 2, 1),
        expected_payment=Decimal("550.00"),
        expected_interest=Decimal("50.00"),
        expected_principal=Decimal("500.00"),
        expected_remaining_principal=Decimal("500.00"),
        paid_amount=Decimal("550.00"),
        status="Paid",
    )
    second = Installment(
        id="installment-2",
        loan_id=loan.id,
        installment_number=2,
        due_date=date(2026, 3, 1),
        expected_payment=Decimal("525.00"),
        expected_interest=Decimal("25.00"),
        expected_principal=Decimal("500.00"),
        expected_remaining_principal=Decimal("0.00"),
        paid_amount=Decimal("0.00"),
        status="Overdue",
    )
    payment = Payment(
        id="payment-1",
        request_id="payment-request-1",
        loan_id=loan.id,
        installment_id=first.id,
        recorded_by_user_id="user-1",
        entry_type="Payment",
        amount=Decimal("550.00"),
        effective_date=date(2026, 2, 1),
        payment_method="unspecified",
        reconciliation_status="unreconciled",
    )
    payment.allocation = PaymentAllocation(
        id="allocation-1",
        interest_before=Decimal("50.00"),
        principal_before=Decimal("1000.00"),
        applied_interest=Decimal("50.00"),
        applied_principal=Decimal("500.00"),
        unapplied_credit=Decimal("0.00"),
        interest_after=Decimal("0.00"),
        principal_after=Decimal("500.00"),
        overdue_days=0,
        scheduled_period_days=31,
    )
    loan.installments = [first, second]
    loan.payments = [payment]
    return loan


class HistoricalPortfolioTests(unittest.TestCase):
    def test_as_of_before_payment_retains_original_principal(self) -> None:
        principal, accrued, overdue = historical_loan_position(
            _loan(), date(2026, 1, 31)
        )
        self.assertEqual(principal, Decimal("1000.00"))
        self.assertEqual(accrued, Decimal("0.00"))
        self.assertEqual(overdue, 0)

    def test_as_of_after_payment_uses_historical_allocation(self) -> None:
        principal, accrued, overdue = historical_loan_position(
            _loan(), date(2026, 3, 31)
        )
        self.assertEqual(principal, Decimal("500.00"))
        self.assertEqual(accrued, Decimal("25.00"))
        self.assertEqual(overdue, 30)

    def test_invalid_business_timezone_is_rejected(self) -> None:
        with self.assertRaises(ValidationError):
            BusinessSettingUpdate(
                business_name="Lender",
                currency_code="PHP",
                receipt_footer="",
                timezone="Not/A_Timezone",
            )
