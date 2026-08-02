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
from app.features.projections.service import (
    compute_loan_financial_summary_dict,
    format_payment_frequency,
    get_loan_last_activity_timestamp,
    get_next_installment_priority,
    get_public_loan_reference,
)

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


def _map_loan_to_item(loan: Loan, today: date) -> BorrowerLoanListItem:
    fin = compute_loan_financial_summary_dict(loan, today)
    next_inst, next_payment_amount, next_due_date, is_overdue = (
        get_next_installment_priority(loan, today)
    )
    loan_ref = get_public_loan_reference(loan)
    last_act = get_loan_last_activity_timestamp(loan)

    return BorrowerLoanListItem(
        id=loan.id,
        loan_reference=loan_ref,
        status=loan.status.lower(),
        principal_amount=fin["principal_amount"],
        total_repayable=fin["total_repayable"],
        amount_paid=fin["amount_paid"],
        outstanding_balance=fin["outstanding_balance"],
        installment_amount=_money(loan.regular_payment_amount),
        payment_frequency=format_payment_frequency(loan.payments_per_month),
        start_date=loan.start_date,
        maturity_date=loan.final_due_date,
        next_due_date=next_due_date,
        next_payment_amount=next_payment_amount,
        is_overdue=is_overdue,
        overdue_amount=fin["overdue_amount"],
        updated_at=last_act,
    )


def _map_loan_to_detail(loan: Loan, today: date) -> BorrowerLoanDetailResponse:
    fin = compute_loan_financial_summary_dict(loan, today)
    next_inst, next_payment_amount, next_due_date, is_overdue = (
        get_next_installment_priority(loan, today)
    )
    loan_ref = get_public_loan_reference(loan)
    last_act = get_loan_last_activity_timestamp(loan)

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

    financial_summary = BorrowerLoanFinancialSummary(
        principal_amount=fin["principal_amount"],
        interest_amount=fin["interest_amount"],
        fees_amount=fin["fees_amount"],
        total_repayable=fin["total_repayable"],
        amount_paid=fin["amount_paid"],
        outstanding_balance=fin["outstanding_balance"],
        overdue_amount=fin["overdue_amount"],
    )

    interest_rate_pct = _money(Decimal(str(loan.monthly_rate)) * Decimal("100.0"))

    terms = BorrowerLoanTerms(
        payment_frequency=format_payment_frequency(loan.payments_per_month),
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
        last_updated=last_act,
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
