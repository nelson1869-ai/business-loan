"""Borrower portal dashboard aggregation service."""

from datetime import UTC, date, datetime
from decimal import ROUND_HALF_UP, Decimal

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.features.borrower_portal.dashboard_schemas import (
    BorrowerDashboardResponse,
    BorrowerSummaryInfo,
    DashboardRecentPayment,
    DashboardSummary,
)
from app.features.borrower_portal.models import BorrowerAccount
from app.features.borrowers.models import Borrower
from app.features.loans.models import Loan
from app.features.payments.models import Payment
from app.features.projections.service import (
    build_loan_financial_projection,
    build_loan_last_activity_timestamp,
    fetch_loan_installments,
)

ZERO = Decimal("0.00")


def _money(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


async def get_borrower_dashboard(
    db: AsyncSession,
    account: BorrowerAccount,
    as_of: date | None = None,
) -> BorrowerDashboardResponse:
    """Aggregate dashboard metrics for the authenticated borrower.

    Derives all loan summaries, balance calculations, next payment amounts,
    and recent payment records exclusively from backend database tables.
    """
    today = as_of or datetime.now(UTC).date()

    # 1. Fetch borrower entity
    borrower = await db.get(Borrower, account.borrower_id)
    if not borrower or borrower.status == "Deleted":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Borrower profile not found or inactive",
        )

    # 2. Fetch all loans for this borrower with their installments
    loans_stmt = (
        select(Loan)
        .options(selectinload(Loan.installments))
        .where(Loan.borrower_id == account.borrower_id)
    )
    loans = list((await db.execute(loans_stmt)).scalars().all())

    collectible_statuses = {"Active", "Overdue", "Defaulted"}
    active_loans = [loan for loan in loans if loan.status in collectible_statuses]
    active_loan_count = len(active_loans)

    # 3. Build financial projections for active loans
    projections = [
        await build_loan_financial_projection(db, loan, today) for loan in active_loans
    ]

    total_outstanding_balance = sum(
        (proj.outstanding_balance for proj in projections), ZERO
    )
    overdue_amount = sum((proj.overdue_amount for proj in projections), ZERO)

    # 4. Evaluate installments across active loans
    all_installments = []
    for loan in active_loans:
        insts = await fetch_loan_installments(db, loan)
        for inst in insts:
            if inst.status not in {"Paid", "Cancelled"}:
                all_installments.append(inst)

    next_payment_amount = ZERO
    next_due_date: date | None = None

    if all_installments:
        all_installments.sort(key=lambda i: (i.due_date, i.installment_number))

        overdue_insts = [i for i in all_installments if i.due_date < today]
        upcoming_insts = [i for i in all_installments if i.due_date >= today]

        # Business Policy: Overdue unpaid installments take priority as next required payment
        next_inst = (
            overdue_insts[0]
            if overdue_insts
            else (upcoming_insts[0] if upcoming_insts else None)
        )
        if next_inst:
            next_payment_amount = max(
                next_inst.expected_payment - next_inst.paid_amount, ZERO
            )
            next_due_date = next_inst.due_date

    # 5. Determine overall loanStatus and paymentStatus
    if overdue_amount > ZERO or any(
        loan.status in {"Overdue", "Defaulted"} for loan in active_loans
    ):
        loan_status = "overdue"
        payment_status = "overdue"
    elif active_loan_count > 0:
        loan_status = "active"
        payment_status = "current"
    else:
        loan_status = "none"
        payment_status = "no_payment_due"

    # 6. Fetch recent payment/reversal for active loans
    recent_payment_dto: DashboardRecentPayment | None = None
    if active_loans:
        active_loan_ids = [loan.id for loan in active_loans]
        recent_stmt = (
            select(Payment)
            .where(
                Payment.loan_id.in_(active_loan_ids),
                Payment.entry_type.in_(["Payment", "Reversal"]),
            )
            .order_by(Payment.created_at.desc())
            .limit(1)
        )
        recent_p = (await db.execute(recent_stmt)).scalar_one_or_none()
        if recent_p:
            receipt_num = (
                getattr(recent_p, "receipt_number", None)
                or f"RCPT-{recent_p.id.replace('-', '').upper()[:12]}"
            )
            recent_payment_dto = DashboardRecentPayment(
                id=recent_p.id,
                amount=_money(recent_p.amount),
                effective_date=recent_p.effective_date,
                entry_type=recent_p.entry_type,
                receipt_number=receipt_num,
            )

    # Derive last_updated from financial activity across active loans
    last_updated_candidates = [
        await build_loan_last_activity_timestamp(db, loan) for loan in active_loans
    ]
    last_updated = (
        max(last_updated_candidates) if last_updated_candidates else datetime.now(UTC)
    )

    summary = DashboardSummary(
        active_loan_count=active_loan_count,
        total_outstanding_balance=_money(total_outstanding_balance),
        next_payment_amount=_money(next_payment_amount),
        next_due_date=next_due_date,
        overdue_amount=_money(overdue_amount),
        loan_status=loan_status,
        payment_status=payment_status,
    )

    borrower_profile = BorrowerSummaryInfo(
        id=borrower.id,
        first_name=borrower.first_name,
        last_name=borrower.last_name,
    )

    return BorrowerDashboardResponse(
        borrower=borrower_profile,
        summary=summary,
        recent_payment=recent_payment_dto,
        last_updated=last_updated,
    )
