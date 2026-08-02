"""Borrower portal dashboard aggregation service."""

from datetime import UTC, date, datetime
from decimal import Decimal

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

ZERO = Decimal("0.00")


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
    now_utc = datetime.now(UTC)

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

    # 3. Calculate total outstanding balance across active loans
    total_outstanding_balance = sum(
        (loan.outstanding_principal for loan in active_loans), ZERO
    )

    # 4. Evaluate installments across active loans
    all_installments = []
    for loan in active_loans:
        for inst in loan.installments:
            if inst.status not in {"Paid", "Cancelled"}:
                all_installments.append(inst)

    next_payment_amount = ZERO
    next_due_date: date | None = None
    overdue_amount = ZERO

    if all_installments:
        all_installments.sort(key=lambda i: (i.due_date, i.installment_number))

        overdue_insts = [i for i in all_installments if i.due_date < today]
        if overdue_insts:
            overdue_amount = sum(
                (i.expected_payment - i.paid_amount for i in overdue_insts), ZERO
            )

        upcoming_insts = [i for i in all_installments if i.due_date >= today]
        if upcoming_insts:
            next_inst = upcoming_insts[0]
            next_payment_amount = next_inst.expected_payment - next_inst.paid_amount
            next_due_date = next_inst.due_date
        elif overdue_insts:
            next_inst = overdue_insts[0]
            next_payment_amount = next_inst.expected_payment - next_inst.paid_amount
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

    # 6. Fetch recent payment for any loan of this borrower
    borrower_loan_ids = [loan.id for loan in loans]
    recent_payment_dto: DashboardRecentPayment | None = None

    if borrower_loan_ids:
        payment_stmt = (
            select(Payment)
            .where(Payment.loan_id.in_(borrower_loan_ids))
            .order_by(Payment.effective_date.desc(), Payment.created_at.desc())
            .limit(1)
        )
        recent_payment = (await db.execute(payment_stmt)).scalar_one_or_none()

        if recent_payment:
            receipt_number = f"RCPT-{recent_payment.id.replace('-', '').upper()[:12]}"
            recent_payment_dto = DashboardRecentPayment(
                id=recent_payment.id,
                amount=recent_payment.amount,
                effective_date=recent_payment.effective_date,
                entry_type=recent_payment.entry_type,
                receipt_number=receipt_number,
            )

    return BorrowerDashboardResponse(
        borrower=BorrowerSummaryInfo(
            id=borrower.id,
            first_name=borrower.first_name,
            last_name=borrower.last_name,
        ),
        summary=DashboardSummary(
            active_loan_count=active_loan_count,
            total_outstanding_balance=total_outstanding_balance,
            next_payment_amount=next_payment_amount,
            next_due_date=next_due_date,
            overdue_amount=overdue_amount,
            loan_status=loan_status,
            payment_status=payment_status,
        ),
        recent_payment=recent_payment_dto,
        last_updated=now_utc,
    )
