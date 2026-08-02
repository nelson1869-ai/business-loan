"""Service logic for Borrower Portal Loans endpoints."""

from datetime import date
from decimal import ROUND_HALF_UP, Decimal

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.features.borrower_portal.loans_schemas import (
    BorrowerLoanDetailResponse,
    BorrowerLoanFinancialSummary,
    BorrowerLoanListItem,
    BorrowerLoanListResponse,
    BorrowerLoanTerms,
    BorrowerNextInstallment,
)
from app.features.borrower_portal.models import BorrowerAccount
from app.features.loans.models import Loan

ZERO = Decimal("0.00")

STATUS_MAP = {
    "draft": "Draft",
    "active": "Active",
    "paid": "Paid",
    "overdue": "Overdue",
    "defaulted": "Defaulted",
    "cancelled": "Cancelled",
}


def _money(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def _format_frequency(payments_per_month: int) -> str:
    mapping = {
        1: "monthly",
        2: "semi_monthly",
        4: "weekly",
        30: "daily",
    }
    return mapping.get(payments_per_month, f"{payments_per_month}_per_month")


def _map_loan_to_item(loan: Loan, today: date) -> BorrowerLoanListItem:
    total_interest = sum((inst.expected_interest for inst in loan.installments), ZERO)
    total_repayable = _money(loan.original_principal + total_interest)
    amount_paid = sum((inst.paid_amount for inst in loan.installments), ZERO)

    all_insts = sorted(
        loan.installments, key=lambda i: (i.due_date, i.installment_number)
    )

    overdue_insts = [
        inst
        for inst in all_insts
        if inst.due_date < today and inst.status not in {"Paid", "Cancelled"}
    ]
    overdue_amount = sum(
        (max(inst.expected_payment - inst.paid_amount, ZERO) for inst in overdue_insts),
        ZERO,
    )

    upcoming_insts = [
        inst
        for inst in all_insts
        if inst.due_date >= today and inst.status not in {"Paid", "Cancelled"}
    ]

    next_inst = (
        upcoming_insts[0]
        if upcoming_insts
        else (overdue_insts[0] if overdue_insts else None)
    )
    next_payment_amount = (
        max(next_inst.expected_payment - next_inst.paid_amount, ZERO)
        if next_inst
        else ZERO
    )
    next_due_date = next_inst.due_date if next_inst else None

    is_overdue = overdue_amount > ZERO or loan.status in {"Overdue", "Defaulted"}
    loan_ref = loan.request_id if loan.request_id else f"LN-{loan.id[:8].upper()}"

    return BorrowerLoanListItem(
        id=loan.id,
        loan_reference=loan_ref,
        status=loan.status.lower(),
        principal_amount=_money(loan.original_principal),
        total_repayable=total_repayable,
        amount_paid=_money(amount_paid),
        outstanding_balance=_money(loan.outstanding_principal),
        installment_amount=_money(loan.regular_payment_amount),
        payment_frequency=_format_frequency(loan.payments_per_month),
        start_date=loan.start_date,
        maturity_date=loan.final_due_date,
        next_due_date=next_due_date,
        next_payment_amount=_money(next_payment_amount),
        is_overdue=is_overdue,
        overdue_amount=_money(overdue_amount),
        updated_at=loan.created_at,
    )


def _map_loan_to_detail(loan: Loan, today: date) -> BorrowerLoanDetailResponse:
    total_interest = sum((inst.expected_interest for inst in loan.installments), ZERO)
    total_repayable = _money(loan.original_principal + total_interest)
    amount_paid = sum((inst.paid_amount for inst in loan.installments), ZERO)

    all_insts = sorted(
        loan.installments, key=lambda i: (i.due_date, i.installment_number)
    )

    overdue_insts = [
        inst
        for inst in all_insts
        if inst.due_date < today and inst.status not in {"Paid", "Cancelled"}
    ]
    overdue_amount = sum(
        (max(inst.expected_payment - inst.paid_amount, ZERO) for inst in overdue_insts),
        ZERO,
    )

    upcoming_insts = [
        inst
        for inst in all_insts
        if inst.due_date >= today and inst.status not in {"Paid", "Cancelled"}
    ]

    next_inst = (
        upcoming_insts[0]
        if upcoming_insts
        else (overdue_insts[0] if overdue_insts else None)
    )
    next_inst_dto: BorrowerNextInstallment | None = None

    if next_inst:
        rem = max(next_inst.expected_payment - next_inst.paid_amount, ZERO)
        inst_status = "overdue" if next_inst.due_date < today else "upcoming"
        next_inst_dto = BorrowerNextInstallment(
            installment_number=next_inst.installment_number,
            due_date=next_inst.due_date,
            amount_due=_money(next_inst.expected_payment),
            amount_paid=_money(next_inst.paid_amount),
            remaining_amount=_money(rem),
            status=inst_status,
        )

    loan_ref = loan.request_id if loan.request_id else f"LN-{loan.id[:8].upper()}"

    financial_summary = BorrowerLoanFinancialSummary(
        principal_amount=_money(loan.original_principal),
        interest_amount=_money(total_interest),
        fees_amount=ZERO,
        total_repayable=total_repayable,
        amount_paid=_money(amount_paid),
        outstanding_balance=_money(loan.outstanding_principal),
        overdue_amount=_money(overdue_amount),
    )

    interest_rate_pct = _money(Decimal(str(loan.monthly_rate)) * Decimal("100.0"))

    terms = BorrowerLoanTerms(
        payment_frequency=_format_frequency(loan.payments_per_month),
        installment_count=loan.number_of_payments,
        installment_amount=_money(loan.regular_payment_amount),
        interest_rate=interest_rate_pct,
        start_date=loan.start_date,
        maturity_date=loan.final_due_date,
    )

    return BorrowerLoanDetailResponse(
        id=loan.id,
        loan_reference=loan_ref,
        status=loan.status.lower(),
        financial_summary=financial_summary,
        terms=terms,
        next_installment=next_inst_dto,
        last_updated=loan.created_at,
    )


async def get_borrower_loans(
    db: AsyncSession,
    current_account: BorrowerAccount,
    status_filter: str | None = None,
    offset: int = 0,
    limit: int = 20,
) -> BorrowerLoanListResponse:
    """Fetch paginated, borrower-scoped loans for the authenticated identity."""
    query_conditions = [Loan.borrower_id == current_account.borrower_id]

    if status_filter:
        clean_status = status_filter.strip().lower()
        if clean_status not in STATUS_MAP:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Invalid status filter '{status_filter}'. Supported: {list(STATUS_MAP.keys())}",
            )
        query_conditions.append(Loan.status == STATUS_MAP[clean_status])

    # Count total matching records
    count_stmt = select(func.count(Loan.id)).where(*query_conditions)
    total = (await db.execute(count_stmt)).scalar() or 0

    # Fetch page of loans with eager loaded installments
    stmt = (
        select(Loan)
        .options(selectinload(Loan.installments))
        .where(*query_conditions)
        .order_by(Loan.created_at.desc())
        .offset(offset)
        .limit(limit)
    )

    loans = list((await db.execute(stmt)).scalars().all())
    today = date.today()

    items = [_map_loan_to_item(loan, today) for loan in loans]

    return BorrowerLoanListResponse(
        items=items,
        total=total,
        offset=offset,
        limit=limit,
    )


async def get_borrower_loan_detail(
    db: AsyncSession,
    current_account: BorrowerAccount,
    loan_id: str,
) -> BorrowerLoanDetailResponse | None:
    """Fetch one borrower-owned loan by ID, strictly enforcing ownership."""
    stmt = (
        select(Loan)
        .options(selectinload(Loan.installments))
        .where(
            Loan.id == loan_id,
            Loan.borrower_id == current_account.borrower_id,
        )
    )

    loan = (await db.execute(stmt)).scalar_one_or_none()
    if loan is None:
        return None

    return _map_loan_to_detail(loan, date.today())
