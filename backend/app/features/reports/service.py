"""Ledger-backed reproducible report calculations."""

from collections import defaultdict
from datetime import UTC, date, datetime, time
from decimal import Decimal
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.features.business_settings.models import BusinessSetting
from app.features.collection.models import CollectionSession
from app.features.loans.models import Loan
from app.features.payments.models import Payment
from app.features.reports.schemas import (
    AgingBuckets,
    CollectorReconciliationReport,
    CollectorReconciliationRow,
    PortfolioRiskReport,
    WriteOffReport,
    WriteOffReportRow,
)
from app.features.write_offs.models import LoanWriteOff

ZERO = Decimal("0.00")


def historical_loan_position(loan: Loan, as_of: date) -> tuple[Decimal, Decimal, int]:
    """Return principal, accrued interest, and maximum days past due."""
    principal_paid = ZERO
    interest_paid = ZERO
    paid_by_installment: dict[str, Decimal] = defaultdict(lambda: ZERO)
    for payment in loan.payments:
        if payment.effective_date > as_of or payment.allocation is None:
            continue
        sign = Decimal("-1") if payment.entry_type == "Reversal" else Decimal("1")
        principal_paid += sign * payment.allocation.applied_principal
        interest_paid += sign * payment.allocation.applied_interest
        if payment.installment_id is not None:
            paid_by_installment[payment.installment_id] += sign * (
                payment.allocation.applied_principal
                + payment.allocation.applied_interest
            )
    outstanding = max(loan.original_principal - principal_paid, ZERO)
    if loan.write_off is not None and loan.write_off.effective_date <= as_of:
        outstanding = max(outstanding - loan.write_off.amount, ZERO)
    accrued_scheduled = sum(
        (
            installment.expected_interest
            for installment in loan.installments
            if installment.due_date <= as_of
        ),
        ZERO,
    )
    accrued_interest = max(accrued_scheduled - interest_paid, ZERO)
    overdue_days = max(
        (
            (as_of - installment.due_date).days
            for installment in loan.installments
            if installment.due_date < as_of
            and paid_by_installment[installment.id] < installment.expected_payment
        ),
        default=0,
    )
    return outstanding, accrued_interest, overdue_days


async def _settings(db: AsyncSession) -> tuple[str, str]:
    settings = await db.get(BusinessSetting, "default")
    if settings is None:
        return "UTC", "PHP"
    return settings.timezone, settings.currency_code


async def portfolio_risk(db: AsyncSession, as_of: date) -> PortfolioRiskReport:
    timezone, currency = await _settings(db)
    result = await db.execute(
        select(Loan).options(
            selectinload(Loan.installments),
            selectinload(Loan.payments).selectinload(Payment.allocation),
            selectinload(Loan.write_off).selectinload(LoanWriteOff.recoveries),
        )
    )
    positions: list[tuple[Decimal, Decimal, int]] = []
    interest_collected = ZERO
    zone = ZoneInfo(timezone)
    for loan in result.scalars().unique():
        started_at = loan.disbursed_at or loan.activated_at or loan.created_at
        if started_at is not None:
            if started_at.tzinfo is None:
                started_at = started_at.replace(tzinfo=UTC)
            if started_at.astimezone(zone).date() > as_of:
                continue
        position = historical_loan_position(loan, as_of)
        positions.append(position)
        interest_collected += sum(
            (
                (Decimal("-1") if payment.entry_type == "Reversal" else Decimal("1"))
                * payment.allocation.applied_interest
                for payment in loan.payments
                if payment.effective_date <= as_of and payment.allocation is not None
            ),
            ZERO,
        )

    outstanding = sum((position[0] for position in positions), ZERO)
    accrued = sum((position[1] for position in positions), ZERO)

    def par(days: int) -> Decimal:
        return sum(
            (principal for principal, _, overdue in positions if overdue >= days), ZERO
        )

    aging_values = {
        "current": ZERO,
        "days_1_7": ZERO,
        "days_8_30": ZERO,
        "days_31_60": ZERO,
        "days_61_90": ZERO,
        "days_over_90": ZERO,
    }
    for principal, _, overdue in positions:
        key = (
            "current"
            if overdue == 0
            else "days_1_7"
            if overdue <= 7
            else "days_8_30"
            if overdue <= 30
            else "days_31_60"
            if overdue <= 60
            else "days_61_90"
            if overdue <= 90
            else "days_over_90"
        )
        aging_values[key] += principal

    return PortfolioRiskReport(
        as_of=as_of,
        timezone=timezone,
        currency=currency,
        outstanding_principal=outstanding,
        accrued_interest=accrued,
        interest_collected=interest_collected,
        par_1=par(1),
        par_7=par(7),
        par_30=par(30),
        par_60=par(60),
        par_90=par(90),
        aging=AgingBuckets(**aging_values),
    )


async def collector_reconciliation(
    db: AsyncSession, date_from: date, date_to: date
) -> CollectorReconciliationReport:
    timezone, currency = await _settings(db)
    zone = ZoneInfo(timezone)
    utc_from = datetime.combine(date_from, time.min, zone).astimezone(UTC)
    utc_to = datetime.combine(date_to, time.max, zone).astimezone(UTC)
    sessions = list(
        (
            await db.execute(
                select(CollectionSession)
                .where(
                    CollectionSession.created_at >= utc_from,
                    CollectionSession.created_at <= utc_to,
                )
                .order_by(CollectionSession.created_at)
            )
        ).scalars()
    )
    session_ids = [session.id for session in sessions]
    payments = []
    if session_ids:
        payments = list(
            (
                await db.execute(
                    select(Payment).where(
                        Payment.collection_session_id.in_(session_ids)
                    )
                )
            ).scalars()
        )
    cash_by_session: dict[str, Decimal] = defaultdict(lambda: ZERO)
    non_cash_by_session: dict[str, Decimal] = defaultdict(lambda: ZERO)
    for payment in payments:
        sign = Decimal("-1") if payment.entry_type == "Reversal" else Decimal("1")
        target = (
            cash_by_session if payment.payment_method == "cash" else non_cash_by_session
        )
        if payment.collection_session_id is not None:
            target[payment.collection_session_id] += sign * payment.amount
    rows = [
        CollectorReconciliationRow(
            session_id=session.id,
            collector_user_id=session.collector_user_id,
            reviewer_user_id=session.reviewer_user_id,
            opening_cash=session.opening_cash,
            cash_collected=cash_by_session[session.id],
            non_cash_payments=non_cash_by_session[session.id],
            expected_cash=session.expected_cash,
            actual_cash=session.actual_cash,
            variance=session.cash_variance,
            deposit_amount=session.deposit_amount,
            deposit_reference=session.deposit_reference,
            status=session.status,
        )
        for session in sessions
    ]
    return CollectorReconciliationReport(
        date_from=date_from,
        date_to=date_to,
        timezone=timezone,
        currency=currency,
        rows=rows,
    )


async def write_off_report(
    db: AsyncSession, date_from: date, date_to: date
) -> WriteOffReport:
    _, currency = await _settings(db)
    write_offs = list(
        (
            await db.execute(
                select(LoanWriteOff)
                .options(selectinload(LoanWriteOff.recoveries))
                .where(
                    LoanWriteOff.effective_date >= date_from,
                    LoanWriteOff.effective_date <= date_to,
                )
                .order_by(LoanWriteOff.effective_date, LoanWriteOff.id)
            )
        ).scalars()
    )
    rows = []
    for write_off in write_offs:
        recovered = sum(
            (
                recovery.amount
                for recovery in write_off.recoveries
                if recovery.effective_date <= date_to
            ),
            ZERO,
        )
        rows.append(
            WriteOffReportRow(
                loan_id=write_off.loan_id,
                write_off_date=write_off.effective_date,
                written_off_amount=write_off.amount,
                recovered_amount=recovered,
                unrecovered_amount=max(write_off.amount - recovered, ZERO),
            )
        )
    return WriteOffReport(
        date_from=date_from,
        date_to=date_to,
        currency=currency,
        total_written_off=sum((row.written_off_amount for row in rows), ZERO),
        total_recovered=sum((row.recovered_amount for row in rows), ZERO),
        rows=rows,
    )
