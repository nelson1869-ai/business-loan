"""Loan account creation, schedule persistence, and queries."""

import json
from calendar import monthrange
from datetime import date, timedelta
from decimal import Decimal
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.audit_log import AuditLog
from app.models.loan import Installment, Loan
from app.models.user import User
from app.schemas.loan import LoanCreate
from app.services.loan_calculator import build_installment_schedule


def _add_months(value: date, months: int) -> date:
    """Move a date by whole calendar months, clamping short months safely."""
    month_index = value.month - 1 + months
    year = value.year + month_index // 12
    month = month_index % 12 + 1
    day = min(value.day, monthrange(year, month)[1])
    return date(year, month, day)


def build_due_dates(payload: LoanCreate) -> tuple[date, ...]:
    """Generate lender-approved dates from a monthly anchor and frequency."""
    dates: list[date] = []
    for month_offset in range(payload.term_months):
        anchor = _add_months(payload.first_due_date, month_offset)
        for payment_index in range(payload.payments_per_month):
            day_offset = (30 * payment_index) // payload.payments_per_month
            dates.append(anchor + timedelta(days=day_offset))
    return tuple(dates)


async def create_loan(db: AsyncSession, payload: LoanCreate, user: User) -> Loan:
    """Create a loan, its calculated schedule, and an audit event atomically."""
    periodic_rate = payload.monthly_rate / Decimal(payload.payments_per_month)
    calculations = build_installment_schedule(
        payload.original_principal,
        periodic_rate,
        payload.number_of_payments,
    )
    due_dates = build_due_dates(payload)
    loan_id = str(uuid4())
    loan = Loan(
        id=loan_id,
        request_id=payload.request_id or str(uuid4()),
        borrower_id=payload.borrower_id,
        created_by_user_id=user.id,
        original_principal=payload.original_principal,
        outstanding_principal=payload.original_principal,
        monthly_rate=payload.monthly_rate,
        term_months=payload.term_months,
        payments_per_month=payload.payments_per_month,
        number_of_payments=payload.number_of_payments,
        regular_payment_amount=calculations[0].payment_amount,
        calculation_method=payload.calculation_method,
        start_date=payload.start_date,
        first_due_date=due_dates[0],
        final_due_date=due_dates[-1],
        status="Active",
    )
    loan.installments = [
        Installment(
            id=str(uuid4()),
            loan_id=loan_id,
            installment_number=item.number,
            due_date=due_date,
            expected_payment=item.payment_amount,
            expected_interest=item.interest_amount,
            expected_principal=item.principal_amount,
            expected_remaining_principal=item.remaining_principal,
            paid_amount=Decimal("0.00"),
            status="Scheduled",
        )
        for item, due_date in zip(calculations, due_dates, strict=True)
    ]
    db.add(loan)
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=user.id,
            action="CREATE_LOAN",
            entity_name="loans",
            entity_id=loan.id,
            old_state_json=None,
            new_state_json=json.dumps(
                {
                    "id": loan.id,
                    "borrowerId": loan.borrower_id,
                    "status": loan.status,
                    "numberOfPayments": loan.number_of_payments,
                }
            ),
        )
    )
    await db.flush()
    return loan


def loan_matches_request(loan: Loan, payload: LoanCreate, user_id: str) -> bool:
    """Return whether a stored loan represents exactly the retried request."""
    return (
        loan.borrower_id == payload.borrower_id
        and loan.created_by_user_id == user_id
        and loan.original_principal == payload.original_principal
        and loan.monthly_rate == payload.monthly_rate
        and loan.term_months == payload.term_months
        and loan.payments_per_month == payload.payments_per_month
        and loan.start_date == payload.start_date
        and loan.first_due_date == payload.first_due_date
        and loan.calculation_method == payload.calculation_method
    )


async def get_loan_by_request_id(
    db: AsyncSession,
    request_id: str,
) -> Loan | None:
    """Return the loan and schedule previously created for a request UUID."""
    result = await db.execute(
        select(Loan)
        .options(selectinload(Loan.installments))
        .where(Loan.request_id == request_id)
    )
    return result.scalar_one_or_none()


async def list_loans(
    db: AsyncSession,
    borrower_id: str | None = None,
    loan_status: str | None = None,
) -> list[Loan]:
    """List loans, optionally filtered by borrower and account status."""
    query = select(Loan)
    if borrower_id is not None:
        query = query.where(Loan.borrower_id == borrower_id)
    if loan_status is not None:
        query = query.where(Loan.status == loan_status)
    result = await db.execute(query.order_by(Loan.created_at.desc()))
    return list(result.scalars())


async def get_loan(db: AsyncSession, loan_id: str) -> Loan | None:
    """Return one loan with its ordered installment schedule."""
    result = await db.execute(
        select(Loan)
        .options(selectinload(Loan.installments))
        .where(Loan.id == loan_id)
    )
    return result.scalar_one_or_none()
