"""Payment preview, locking, immutable persistence, and balance updates."""

import json
from datetime import date
from decimal import Decimal, ROUND_HALF_UP
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.audit_log import AuditLog
from app.models.loan import Installment, Loan
from app.models.payment import Payment, PaymentAllocation
from app.models.user import User
from app.schemas.payment import PaymentCreate, PaymentPreviewRequest, PaymentPreviewResponse
from app.services.loan_calculator import (
    CENT,
    LoanCalculationError,
    allocate_payment,
    calculate_period_interest,
    calculate_prorated_interest,
)


def build_payment_preview(
    loan: Loan,
    installment: Installment,
    payment_amount: Decimal,
    effective_date: date,
    period_start_date: date,
    carried_interest_due: Decimal = Decimal("0.00"),
    accrual_start_date: date | None = None,
) -> PaymentPreviewResponse:
    """Calculate an exact interest-first allocation without changing state."""
    if installment.loan_id != loan.id:
        raise LoanCalculationError("installment must belong to the loan")
    if effective_date < period_start_date:
        raise LoanCalculationError("effective_date must not precede the period start")
    accrual_start = accrual_start_date or period_start_date
    if accrual_start < period_start_date:
        raise LoanCalculationError("accrual_start_date must not precede the period start")
    if effective_date < accrual_start:
        raise LoanCalculationError("effective_date must not precede the accrual start")
    scheduled_period_days = (installment.due_date - period_start_date).days
    if scheduled_period_days <= 0:
        raise LoanCalculationError("installment due date must follow the period start")
    if carried_interest_due < 0:
        raise LoanCalculationError("carried_interest_due must not be negative")

    elapsed_days = (effective_date - accrual_start).days
    overdue_days = max((effective_date - installment.due_date).days, 0)
    days_early = max((installment.due_date - effective_date).days, 0)
    periodic_rate = loan.monthly_rate / Decimal(loan.payments_per_month)
    accrued_interest = calculate_prorated_interest(
        loan.outstanding_principal,
        periodic_rate,
        elapsed_days,
        scheduled_period_days,
    )
    carried_interest = carried_interest_due.quantize(CENT, rounding=ROUND_HALF_UP)
    total_interest = (accrued_interest + carried_interest).quantize(
        CENT,
        rounding=ROUND_HALF_UP,
    )
    allocation = allocate_payment(
        payment_amount,
        total_interest,
        loan.outstanding_principal,
    )
    amount_above_scheduled = max(
        allocation.payment_amount - installment.expected_payment,
        Decimal("0.00"),
    )
    next_period_interest = calculate_period_interest(
        allocation.remaining_principal,
        periodic_rate,
    )

    return PaymentPreviewResponse(
        loan_id=loan.id,
        installment_id=installment.id,
        payment_amount=allocation.payment_amount,
        effective_date=effective_date,
        period_start_date=period_start_date,
        accrual_start_date=accrual_start,
        due_date=installment.due_date,
        scheduled_period_days=scheduled_period_days,
        elapsed_days=elapsed_days,
        days_early=days_early,
        overdue_days=overdue_days,
        periodic_rate=periodic_rate,
        accrued_interest=accrued_interest,
        carried_interest_before=carried_interest,
        total_interest_before=total_interest,
        principal_before=loan.outstanding_principal,
        applied_interest=allocation.applied_to_interest,
        applied_principal=allocation.applied_to_principal,
        unapplied_credit=allocation.unapplied_credit,
        interest_after=allocation.remaining_interest,
        principal_after=allocation.remaining_principal,
        scheduled_payment=installment.expected_payment,
        amount_above_scheduled=amount_above_scheduled,
        next_period_interest=next_period_interest,
        is_payoff=(
            allocation.remaining_interest == Decimal("0.00")
            and allocation.remaining_principal == Decimal("0.00")
        ),
    )


async def get_payment(db: AsyncSession, payment_id: str) -> Payment | None:
    result = await db.execute(
        select(Payment).options(selectinload(Payment.allocation)).where(Payment.id == payment_id)
    )
    return result.scalar_one_or_none()


async def get_payment_by_request_id(db: AsyncSession, request_id: str) -> Payment | None:
    result = await db.execute(
        select(Payment)
        .options(selectinload(Payment.allocation))
        .where(Payment.request_id == request_id)
    )
    return result.scalar_one_or_none()


async def list_payments(db: AsyncSession, loan_id: str) -> list[Payment]:
    result = await db.execute(
        select(Payment)
        .options(selectinload(Payment.allocation))
        .where(Payment.loan_id == loan_id)
        .order_by(Payment.effective_date.desc(), Payment.created_at.desc())
    )
    return list(result.scalars())


def payment_matches_request(payment: Payment, loan_id: str, payload: PaymentCreate) -> bool:
    """Ensure a retry UUID cannot silently represent different money or terms."""
    return (
        payment.loan_id == loan_id
        and (
            payload.installment_id is None
            or payment.installment_id == payload.installment_id
        )
        and payment.amount == payload.amount
        and payment.effective_date == payload.effective_date
        and payment.note == payload.note
        and payment.entry_type == "Payment"
    )


async def _locked_context(
    db: AsyncSession,
    loan_id: str,
    payload: PaymentPreviewRequest,
) -> tuple[Loan, Installment, date, date, Decimal]:
    result = await db.execute(
        select(Loan)
        .options(selectinload(Loan.installments))
        .where(Loan.id == loan_id)
        .with_for_update()
    )
    loan = result.scalar_one_or_none()
    if loan is None:
        raise LoanCalculationError("loan not found")
    if loan.status not in {"Active", "Overdue"}:
        raise LoanCalculationError("loan does not accept payments")

    candidates = [item for item in loan.installments if item.status not in {"Paid", "Cancelled"}]
    if payload.installment_id is None:
        installment = candidates[0] if candidates else None
    else:
        installment = next((item for item in candidates if item.id == payload.installment_id), None)
    if installment is None:
        raise LoanCalculationError("installment not found or already closed")

    previous = next(
        (item for item in loan.installments if item.installment_number == installment.installment_number - 1),
        None,
    )
    period_start = previous.due_date if previous is not None else loan.start_date
    payments_result = await db.execute(
        select(Payment)
        .options(selectinload(Payment.allocation))
        .where(
            Payment.loan_id == loan.id,
            Payment.installment_id == installment.id,
            Payment.entry_type == "Payment",
        )
        .order_by(Payment.effective_date.desc(), Payment.created_at.desc())
    )
    latest = payments_result.scalars().first()
    accrual_start = latest.effective_date if latest is not None else period_start
    carried_interest = latest.allocation.interest_after if latest is not None else Decimal("0.00")
    return loan, installment, period_start, accrual_start, carried_interest


async def preview_payment(
    db: AsyncSession,
    loan_id: str,
    payload: PaymentPreviewRequest,
) -> PaymentPreviewResponse:
    loan, installment, period_start, accrual_start, carried = await _locked_context(
        db, loan_id, payload
    )
    return build_payment_preview(
        loan,
        installment,
        payload.amount,
        payload.effective_date,
        period_start,
        carried,
        accrual_start,
    )


async def record_payment(
    db: AsyncSession,
    loan_id: str,
    payload: PaymentCreate,
    user: User,
) -> Payment:
    """Recalculate and persist one payment, allocation, balances, and audit atomically."""
    loan, installment, period_start, accrual_start, carried = await _locked_context(
        db, loan_id, payload
    )
    preview = build_payment_preview(
        loan, installment, payload.amount, payload.effective_date,
        period_start, carried, accrual_start,
    )
    payment = Payment(
        id=str(uuid4()), request_id=payload.request_id, loan_id=loan.id,
        installment_id=installment.id, recorded_by_user_id=user.id,
        entry_type="Payment", amount=preview.payment_amount,
        effective_date=payload.effective_date, note=payload.note,
    )
    payment.allocation = PaymentAllocation(
        id=str(uuid4()), interest_before=preview.total_interest_before,
        principal_before=preview.principal_before,
        applied_interest=preview.applied_interest,
        applied_principal=preview.applied_principal,
        unapplied_credit=preview.unapplied_credit,
        interest_after=preview.interest_after,
        principal_after=preview.principal_after,
        overdue_days=preview.overdue_days,
        scheduled_period_days=preview.scheduled_period_days,
    )
    loan.outstanding_principal = preview.principal_after
    installment.paid_amount = (
        installment.paid_amount + preview.applied_interest + preview.applied_principal
    )
    installment.status = (
        "Paid"
        if preview.interest_after == Decimal("0.00")
        and installment.paid_amount >= installment.expected_payment
        else "PartiallyPaid"
    )
    if preview.is_payoff:
        loan.status = "Paid"
        installment.status = "Paid"
        for future in loan.installments:
            if future.installment_number > installment.installment_number:
                future.status = "Cancelled"
    db.add(payment)
    db.add(AuditLog(
        id=str(uuid4()), user_id=user.id, action="CREATE_PAYMENT",
        entity_name="payments", entity_id=payment.id, old_state_json=None,
        new_state_json=json.dumps({
            "loanId": loan.id, "installmentId": installment.id,
            "amount": str(payment.amount), "principalAfter": str(preview.principal_after),
            "interestAfter": str(preview.interest_after),
        }),
    ))
    await db.flush()
    return payment
