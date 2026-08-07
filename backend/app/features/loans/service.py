"""Loan account creation, schedule persistence, and queries."""

import json
from calendar import monthrange
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal
from uuid import uuid4

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.features.admin_assistant.models import AuditLog
from app.features.loan_policies.models import LoanPolicyVersion
from app.features.notifications.service import create_borrower_notification
from app.features.loan_policies.service import policy_snapshot
from app.features.loans.calculator import (
    build_installment_schedule,
    build_interest_only_schedule,
)
from app.features.loans.models import Installment, Loan
from app.features.loans.schemas import (
    LoanCreate,
    LoanQuoteInstallment,
    LoanQuoteRequest,
    LoanQuoteResponse,
)
from app.features.payments.models import Payment
from app.features.users.models import User


def _add_months(value: date, months: int) -> date:
    """Move a date by whole calendar months, clamping short months safely."""
    month_index = value.month - 1 + months
    year = value.year + month_index // 12
    month = month_index % 12 + 1
    day = min(value.day, monthrange(year, month)[1])
    return date(year, month, day)


def build_due_dates(payload: LoanCreate) -> tuple[date, ...]:
    """Generate lender-approved due dates starting from first_due_date.

    - Monthly (payments_per_month = 1):
      Generates 1 payment per month on the same day as first_due_date (clamped to month-end).
    - Twice a Month (payments_per_month = 2):
      Generates 2 payments per month using canonical semi-monthly slots:
      15th and last calendar day of the month.
      The sequence starts at first_due_date (no due dates earlier than first_due_date).
    """
    if payload.payments_per_month == 1:
        dates: list[date] = []
        for month_offset in range(payload.term_months):
            dates.append(_add_months(payload.first_due_date, month_offset))
        return tuple(dates)

    if payload.payments_per_month == 2:
        total_payments = payload.number_of_payments
        dates: list[date] = []
        year = payload.first_due_date.year
        month = payload.first_due_date.month

        while len(dates) < total_payments:
            last_day = monthrange(year, month)[1]
            candidate_15 = date(year, month, 15)
            candidate_last = date(year, month, last_day)

            if candidate_15 >= payload.first_due_date:
                dates.append(candidate_15)
                if len(dates) == total_payments:
                    break

            if candidate_last >= payload.first_due_date:
                dates.append(candidate_last)

            # Advance to next month
            month += 1
            if month > 12:
                month = 1
                year += 1

        return tuple(dates)

    # Fallback for historical/other frequencies
    dates: list[date] = []
    for month_offset in range(payload.term_months):
        anchor = _add_months(payload.first_due_date, month_offset)
        for payment_index in range(payload.payments_per_month):
            day_offset = (30 * payment_index) // payload.payments_per_month
            dates.append(anchor + timedelta(days=day_offset))
    return tuple(dates)


def build_quote(payload: LoanQuoteRequest) -> LoanQuoteResponse:
    """Calculate an indicative schedule without reading or writing the database."""
    periodic_rate = payload.monthly_rate / Decimal(payload.payments_per_month)
    if payload.repayment_structure == "interest_only":
        calculations = build_interest_only_schedule(
            payload.original_principal,
            periodic_rate,
            payload.number_of_payments,
        )
    else:
        calculations = build_installment_schedule(
            payload.original_principal,
            periodic_rate,
            payload.number_of_payments,
        )
    date_terms = LoanCreate(
        borrower_id="00000000-0000-0000-0000-000000000000",
        original_principal=payload.original_principal,
        monthly_rate=payload.monthly_rate,
        term_months=payload.term_months,
        payments_per_month=payload.payments_per_month,
        start_date=payload.first_due_date - timedelta(days=1),
        first_due_date=payload.first_due_date,
        calculation_method=payload.calculation_method,
        repayment_structure=payload.repayment_structure,
    )
    due_dates = build_due_dates(date_terms)
    total_interest = sum(
        (item.interest_amount for item in calculations), Decimal("0.00")
    )
    total_repayment = sum(
        (item.payment_amount for item in calculations), Decimal("0.00")
    )
    return LoanQuoteResponse(
        original_principal=payload.original_principal,
        monthly_rate=payload.monthly_rate,
        term_months=payload.term_months,
        payments_per_month=payload.payments_per_month,
        number_of_payments=payload.number_of_payments,
        regular_payment_amount=calculations[0].payment_amount,
        total_interest=total_interest,
        total_repayment=total_repayment,
        final_due_date=due_dates[-1],
        calculation_method=payload.calculation_method,
        repayment_structure=payload.repayment_structure,
        installments=[
            LoanQuoteInstallment(
                installment_number=item.number,
                due_date=due_date,
                payment_amount=item.payment_amount,
                interest_amount=item.interest_amount,
                principal_amount=item.principal_amount,
                remaining_principal=item.remaining_principal,
            )
            for item, due_date in zip(calculations, due_dates, strict=True)
        ],
    )


async def create_loan(
    db: AsyncSession, payload: LoanCreate, user: User, *, initial_status: str = "Active"
) -> Loan:
    """Create a loan, its calculated schedule, and an audit event atomically."""
    selected_policy = None
    if payload.policy_version_id is not None:
        selected_policy = await db.get(LoanPolicyVersion, payload.policy_version_id)
        if selected_policy is None or selected_policy.status != "active":
            raise ValueError("An active loan policy version is required")
        if not (
            selected_policy.minimum_rate
            <= payload.monthly_rate
            <= selected_policy.maximum_rate
        ):
            raise ValueError("Loan rate is outside the selected policy range")
        if selected_policy.interest_method != payload.calculation_method:
            raise ValueError(
                "Loan calculation method does not match the selected policy"
            )
    periodic_rate = payload.monthly_rate / Decimal(payload.payments_per_month)
    if payload.repayment_structure == "interest_only":
        calculations = build_interest_only_schedule(
            payload.original_principal,
            periodic_rate,
            payload.number_of_payments,
        )
    else:
        calculations = build_installment_schedule(
            payload.original_principal,
            periodic_rate,
            payload.number_of_payments,
        )
    due_dates = build_due_dates(payload)
    # Offline clients use request_id as the canonical resource id so dependent
    # queued mutations (payments, notes, documents) remain addressable after
    # loan creation is replayed on the server.
    loan_id = payload.request_id or str(uuid4())
    loan = Loan(
        id=loan_id,
        request_id=payload.request_id or str(uuid4()),
        borrower_id=payload.borrower_id,
        created_by_user_id=user.id,
        policy_version_id=selected_policy.id if selected_policy else None,
        policy_snapshot=(
            policy_snapshot(selected_policy)
            if selected_policy
            else {
                "source": "legacy-explicit-terms",
                "calculationMethod": payload.calculation_method,
                "repaymentStructure": payload.repayment_structure,
                "monthlyRate": str(payload.monthly_rate),
                "rounding": "ROUND_HALF_UP",
                "paymentAllocationOrder": ["interest", "principal", "unapplied_credit"],
            }
        ),
        original_principal=payload.original_principal,
        outstanding_principal=payload.original_principal,
        monthly_rate=payload.monthly_rate,
        term_months=payload.term_months,
        payments_per_month=payload.payments_per_month,
        number_of_payments=payload.number_of_payments,
        regular_payment_amount=calculations[0].payment_amount,
        calculation_method=payload.calculation_method,
        repayment_structure=payload.repayment_structure,
        start_date=payload.start_date,
        first_due_date=due_dates[0],
        final_due_date=due_dates[-1],
        status=initial_status,
        activated_at=datetime.now(UTC) if initial_status == "Active" else None,
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
        and loan.policy_version_id == payload.policy_version_id
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
        .options(
            selectinload(Loan.installments),
            selectinload(Loan.payments).selectinload(Payment.allocation),
        )
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


async def page_loans(
    db: AsyncSession,
    borrower_id: str | None,
    loan_status: str | None,
    offset: int,
    limit: int,
) -> tuple[list[Loan], int]:
    """Return a stable loan page and total without changing the legacy list."""
    filters = []
    if borrower_id is not None:
        filters.append(Loan.borrower_id == borrower_id)
    if loan_status is not None:
        filters.append(Loan.status == loan_status)
    total = await db.scalar(select(func.count()).select_from(Loan).where(*filters)) or 0
    result = await db.execute(
        select(Loan)
        .where(*filters)
        .order_by(Loan.created_at.desc(), Loan.id.desc())
        .offset(offset)
        .limit(limit)
    )
    return list(result.scalars()), total


async def get_loan(db: AsyncSession, loan_id: str) -> Loan | None:
    """Return one loan with its ordered installment schedule and payment allocations."""
    result = await db.execute(
        select(Loan)
        .options(
            selectinload(Loan.installments),
            selectinload(Loan.payments).selectinload(Payment.allocation),
        )
        .where(Loan.id == loan_id)
    )
    return result.scalar_one_or_none()


async def transition_loan(
    db: AsyncSession, loan_id: str, action: str, user: User
) -> tuple[Loan, datetime]:
    """Apply one validated lifecycle command without bypassing ledger rules."""
    result = await db.execute(
        select(Loan)
        .options(selectinload(Loan.installments), selectinload(Loan.payments))
        .where(Loan.id == loan_id)
        .with_for_update()
    )
    loan = result.scalar_one_or_none()
    if loan is None:
        raise ValueError("Loan not found")
    now = datetime.now(UTC)
    if action == "approve":
        if loan.status != "Draft" or loan.approved_at is not None:
            raise ValueError("Only an unapproved draft may be approved")
        loan.approved_at = now
        loan.approved_by_user_id = user.id
    elif action == "approve_and_activate":
        # Single-owner shortcut: approve + disburse + activate in one atomic step.
        if loan.status != "Draft" or loan.approved_at is not None:
            raise ValueError("Only an unapproved draft may be approved")
        loan.approved_at = now
        loan.approved_by_user_id = user.id
        loan.disbursed_at = now
        loan.disbursed_by_user_id = user.id
        loan.status = "Active"
        loan.activated_at = now
    elif action == "disburse":
        if (
            loan.status != "Draft"
            or loan.approved_at is None
            or loan.disbursed_at is not None
        ):
            raise ValueError("An approved draft is required before disbursement")
        loan.disbursed_at = now
        loan.disbursed_by_user_id = user.id
    elif action == "activate":
        if loan.status != "Draft" or loan.disbursed_at is None:
            raise ValueError("A disbursed draft is required before activation")
        loan.status, loan.activated_at = "Active", now
    elif action == "complete":
        if loan.status not in {
            "Active",
            "Overdue",
        } or loan.outstanding_principal != Decimal("0.00"):
            raise ValueError("Only a fully repaid active loan may be completed")
        loan.status, loan.completed_at = "Paid", now
    elif action == "default":
        if loan.status not in {"Active", "Overdue"}:
            raise ValueError("Only an active or overdue loan may default")
        loan.status, loan.defaulted_at = "Defaulted", now
    elif action == "cancel":
        if loan.status != "Draft" or loan.payments:
            raise ValueError("Only an unpaid draft may be cancelled")
        loan.status, loan.cancelled_at = "Cancelled", now
        for installment in loan.installments:
            installment.status = "Cancelled"
    elif action == "close":
        if loan.status != "Paid" or loan.closed_at is not None:
            raise ValueError("Only a paid, open loan may be closed")
        loan.closed_at = now
    else:
        raise ValueError("Unsupported workflow action")
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=user.id,
            action=f"LOAN_{action.upper()}",
            entity_name="loans",
            entity_id=loan.id,
            old_state_json=None,
            new_state_json=json.dumps(
                {"status": loan.status, "occurredAt": now.isoformat()}
            ),
        )
    )

    if loan.status == "Active":
        await create_borrower_notification(
            db,
            borrower_id=loan.borrower_id,
            notification_type="loan_activated",
            title="Loan Activated",
            message=(
                f"Your loan ({loan.id[:8]}) of "
                f"₱{loan.original_principal:,.2f} is now active."
            ),
            entity_type="loan",
            entity_id=loan.id,
            metadata={"loan_id": loan.id},
            deduplication_key=f"loan_activated:{loan.id}",
        )

    await db.flush()
    return loan, now
