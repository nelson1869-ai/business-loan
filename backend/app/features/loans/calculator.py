"""Exact decimal calculations for loan interest and payment allocation."""

from dataclasses import dataclass
from decimal import ROUND_HALF_UP, Decimal

CENT = Decimal("0.01")


class LoanCalculationError(ValueError):
    """Raised when a loan calculation receives an invalid value."""


@dataclass(frozen=True, slots=True)
class PaymentAllocation:
    """Result of allocating one payment to interest, principal, and credit."""

    payment_amount: Decimal
    applied_to_interest: Decimal
    applied_to_principal: Decimal
    unapplied_credit: Decimal
    remaining_interest: Decimal
    remaining_principal: Decimal


@dataclass(frozen=True, slots=True)
class Installment:
    """One scheduled payment with its interest and principal allocation."""

    number: int
    payment_amount: Decimal
    interest_amount: Decimal
    principal_amount: Decimal
    remaining_principal: Decimal


def _money(value: Decimal, field_name: str) -> Decimal:
    """Validate a non-negative Decimal monetary value and round it to cents."""
    if not isinstance(value, Decimal):
        raise LoanCalculationError(f"{field_name} must be a Decimal")
    if not value.is_finite():
        raise LoanCalculationError(f"{field_name} must be finite")
    if value < 0:
        raise LoanCalculationError(f"{field_name} must not be negative")
    return value.quantize(CENT, rounding=ROUND_HALF_UP)


def _rate(value: Decimal) -> Decimal:
    """Validate a non-negative finite Decimal rate without cent rounding."""
    if not isinstance(value, Decimal):
        raise LoanCalculationError("rate must be a Decimal")
    if not value.is_finite():
        raise LoanCalculationError("rate must be finite")
    if value < 0:
        raise LoanCalculationError("rate must not be negative")
    return value


def calculate_period_interest(
    outstanding_principal: Decimal,
    periodic_rate: Decimal,
) -> Decimal:
    """Calculate one scheduled period's interest on outstanding principal."""
    principal = _money(outstanding_principal, "outstanding_principal")
    rate = _rate(periodic_rate)
    return (principal * rate).quantize(CENT, rounding=ROUND_HALF_UP)


def calculate_prorated_interest(
    outstanding_principal: Decimal,
    periodic_rate: Decimal,
    elapsed_days: int,
    scheduled_period_days: int,
) -> Decimal:
    """Calculate interest for an early, late, or irregular partial period."""
    principal = _money(outstanding_principal, "outstanding_principal")
    rate = _rate(periodic_rate)
    if not isinstance(elapsed_days, int) or isinstance(elapsed_days, bool):
        raise LoanCalculationError("elapsed_days must be an integer")
    if not isinstance(scheduled_period_days, int) or isinstance(
        scheduled_period_days, bool
    ):
        raise LoanCalculationError("scheduled_period_days must be an integer")
    if elapsed_days < 0:
        raise LoanCalculationError("elapsed_days must not be negative")
    if scheduled_period_days <= 0:
        raise LoanCalculationError("scheduled_period_days must be positive")

    day_fraction = Decimal(elapsed_days) / Decimal(scheduled_period_days)
    return (principal * rate * day_fraction).quantize(
        CENT,
        rounding=ROUND_HALF_UP,
    )


def allocate_payment(
    payment_amount: Decimal,
    interest_due: Decimal,
    outstanding_principal: Decimal,
) -> PaymentAllocation:
    """Allocate a payment to interest first, then principal, then credit."""
    payment = _money(payment_amount, "payment_amount")
    interest = _money(interest_due, "interest_due")
    principal = _money(outstanding_principal, "outstanding_principal")

    applied_interest = min(payment, interest)
    after_interest = payment - applied_interest
    applied_principal = min(after_interest, principal)
    credit = after_interest - applied_principal

    return PaymentAllocation(
        payment_amount=payment,
        applied_to_interest=applied_interest,
        applied_to_principal=applied_principal,
        unapplied_credit=credit,
        remaining_interest=interest - applied_interest,
        remaining_principal=principal - applied_principal,
    )


def build_installment_schedule(
    original_principal: Decimal,
    periodic_rate: Decimal,
    number_of_payments: int,
) -> tuple[Installment, ...]:
    """Build regular installments and adjust the final payment to reach zero."""
    principal = _money(original_principal, "original_principal")
    rate = _rate(periodic_rate)
    if principal <= 0:
        raise LoanCalculationError("original_principal must be positive")
    if not isinstance(number_of_payments, int) or isinstance(number_of_payments, bool):
        raise LoanCalculationError("number_of_payments must be an integer")
    if number_of_payments <= 0:
        raise LoanCalculationError("number_of_payments must be positive")

    payment_count = Decimal(number_of_payments)
    if rate == 0:
        exact_regular_payment = principal / payment_count
    else:
        discount_factor = Decimal(1) - (Decimal(1) + rate) ** (-number_of_payments)
        exact_regular_payment = principal * rate / discount_factor
    regular_payment = exact_regular_payment.quantize(CENT, rounding=ROUND_HALF_UP)

    balance = principal
    installments: list[Installment] = []
    for number in range(1, number_of_payments + 1):
        interest = calculate_period_interest(balance, rate)
        is_final_payment = number == number_of_payments
        payment = (
            (balance + interest).quantize(CENT, rounding=ROUND_HALF_UP)
            if is_final_payment
            else regular_payment
        )
        principal_paid = (payment - interest).quantize(
            CENT,
            rounding=ROUND_HALF_UP,
        )
        if principal_paid <= 0:
            raise LoanCalculationError(
                "regular payment must be greater than period interest"
            )
        remaining = (balance - principal_paid).quantize(
            CENT,
            rounding=ROUND_HALF_UP,
        )
        if is_final_payment:
            remaining = Decimal("0.00")

        installments.append(
            Installment(
                number=number,
                payment_amount=payment,
                interest_amount=interest,
                principal_amount=principal_paid,
                remaining_principal=remaining,
            )
        )
        balance = remaining

    return tuple(installments)
