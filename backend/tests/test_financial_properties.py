"""Property-based tests for exact financial invariants."""

from decimal import Decimal

from hypothesis import assume, given, settings
from hypothesis import strategies as st

from app.features.accounting.service import repayment_lines, validate_balanced_lines
from app.features.loans.calculator import (
    LoanCalculationError,
    allocate_payment,
    build_installment_schedule,
)

money = st.integers(min_value=0, max_value=100_000_000).map(
    lambda cents: Decimal(cents) / Decimal(100)
)
positive_money = st.integers(min_value=1, max_value=100_000_000).map(
    lambda cents: Decimal(cents) / Decimal(100)
)
rates = st.integers(min_value=0, max_value=200_000).map(
    lambda millionths: Decimal(millionths) / Decimal(1_000_000)
)


@settings(max_examples=250, deadline=None)
@given(payment=money, interest=money, principal=money)
def test_payment_allocation_conserves_value_and_never_overallocates(
    payment: Decimal, interest: Decimal, principal: Decimal
) -> None:
    allocation = allocate_payment(payment, interest, principal)

    assert (
        allocation.applied_to_interest
        + allocation.applied_to_principal
        + allocation.unapplied_credit
        == allocation.payment_amount
    )
    assert allocation.applied_to_interest <= interest
    assert allocation.applied_to_principal <= principal
    assert allocation.remaining_interest >= Decimal("0.00")
    assert allocation.remaining_principal >= Decimal("0.00")


@settings(max_examples=150, deadline=None)
@given(
    principal=positive_money, rate=rates, count=st.integers(min_value=1, max_value=120)
)
def test_schedule_settles_exactly_without_negative_balances(
    principal: Decimal, rate: Decimal, count: int
) -> None:
    # A cent-denominated schedule cannot contain more installments than
    # principal cents without zero-principal installments.
    assume(principal >= Decimal(count) * Decimal("0.01"))
    try:
        schedule = build_installment_schedule(principal, rate, count)
    except LoanCalculationError:
        # Some cent-denominated principal/rate/term combinations cannot produce
        # even one cent of principal per installment and are correctly rejected.
        assume(False)

    assert len(schedule) == count
    assert schedule[-1].remaining_principal == Decimal("0.00")
    assert all(item.remaining_principal >= Decimal("0.00") for item in schedule)
    assert (
        sum((item.principal_amount for item in schedule), Decimal("0.00")) == principal
    )


@settings(max_examples=200, deadline=None)
@given(principal=money, interest=money, credit=money)
def test_repayment_journal_always_balances_allocations(
    principal: Decimal, interest: Decimal, credit: Decimal
) -> None:
    amount = principal + interest + credit
    if amount == Decimal("0.00"):
        return
    lines = repayment_lines(
        amount=amount,
        principal=principal,
        interest=interest,
        unapplied_credit=credit,
    )
    debit, posted_credit = validate_balanced_lines(lines)
    assert debit == amount
    assert posted_credit == amount
