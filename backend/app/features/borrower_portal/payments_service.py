"""Service logic for Borrower Portal Payments & Receipts endpoints."""

from decimal import Decimal
from typing import Sequence

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.features.borrower_portal.models import BorrowerAccount
from app.features.borrower_portal.payments_schemas import (
    BorrowerPaymentHistoryResponse,
    BorrowerPaymentListItemResponse,
    BorrowerReceiptDetailResponse,
)
from app.features.loans.models import Loan
from app.features.payments.models import Payment, PaymentAllocation
from app.features.projections.service import get_public_loan_reference

ZERO = Decimal("0.00")


def _money(val: Decimal | None) -> Decimal:
    """Format Decimal to two places."""
    if val is None:
        return ZERO
    return val.quantize(Decimal("0.01"))


def format_receipt_number(payment_id: str) -> str:
    """Generate canonical receipt reference string."""
    clean_id = payment_id.replace("-", "").upper()
    return f"RCPT-{clean_id[:12]}"


async def get_borrower_loan_payments(
    db: AsyncSession,
    current_account: BorrowerAccount,
    loan_id: str,
) -> BorrowerPaymentHistoryResponse:
    """Fetch borrower-scoped payment history for a specific loan."""
    stmt_loan = select(Loan).where(
        Loan.id == loan_id,
        Loan.borrower_id == current_account.borrower_id,
    )
    loan = (await db.execute(stmt_loan)).scalar_one_or_none()

    if not loan:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Loan account not found",
        )

    stmt_payments = (
        select(Payment)
        .where(Payment.loan_id == loan_id)
        .order_by(Payment.effective_date.desc(), Payment.created_at.desc())
    )
    res = await db.execute(stmt_payments)
    payments: Sequence[Payment] = res.scalars().all()

    items: list[BorrowerPaymentListItemResponse] = []
    for p in payments:
        pmt_status = "reversed" if p.entry_type == "Reversal" else "posted"
        items.append(
            BorrowerPaymentListItemResponse(
                id=p.id,
                receipt_number=format_receipt_number(p.id),
                effective_date=p.effective_date,
                amount=_money(p.amount),
                entry_type=p.entry_type.lower(),
                status=pmt_status,
                created_at=p.created_at,
            )
        )

    return BorrowerPaymentHistoryResponse(
        items=items,
        total_count=len(items),
    )


async def get_borrower_payment_receipt(
    db: AsyncSession,
    current_account: BorrowerAccount,
    payment_id: str,
) -> BorrowerReceiptDetailResponse:
    """Fetch digital receipt overview with allocation breakdown for a borrower payment."""
    stmt = (
        select(Payment)
        .options(
            selectinload(Payment.loan),
            selectinload(Payment.allocation),
        )
        .where(Payment.id == payment_id)
    )
    res = await db.execute(stmt)
    payment = res.scalar_one_or_none()

    if not payment or payment.loan.borrower_id != current_account.borrower_id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Payment receipt not found",
        )

    alloc: PaymentAllocation | None = payment.allocation
    loan_ref = get_public_loan_reference(payment.loan)

    principal_paid = _money(alloc.applied_principal) if alloc else ZERO
    interest_paid = _money(alloc.applied_interest) if alloc else ZERO
    unapplied_credit = _money(alloc.unapplied_credit) if alloc else ZERO
    remaining_balance = _money(alloc.principal_after) if alloc else _money(payment.loan.outstanding_principal)

    pmt_status = "reversed" if payment.entry_type == "Reversal" else "posted"

    return BorrowerReceiptDetailResponse(
        receipt_number=format_receipt_number(payment.id),
        payment_id=payment.id,
        loan_id=payment.loan_id,
        loan_reference=loan_ref,
        payment_date=payment.effective_date,
        amount_received=_money(payment.amount),
        principal_paid=principal_paid,
        interest_paid=interest_paid,
        penalty_paid=ZERO,
        unapplied_credit=unapplied_credit,
        remaining_balance=remaining_balance,
        entry_type=payment.entry_type.lower(),
        status=pmt_status,
        recorded_at=payment.created_at,
    )
