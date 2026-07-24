"""Ledger-backed receipt, statement, dashboard, and report projections."""

from datetime import UTC, date, datetime
from decimal import ROUND_HALF_UP, Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.borrower import Borrower
from app.models.loan import Installment, Loan
from app.models.payment import Payment
from app.schemas.loan import InstallmentResponse, LoanResponse
from app.schemas.payment import PaymentResponse
from app.schemas.projections import (
    DashboardProjection,
    FinancialReportProjection,
    LoanStatementProjection,
    PartySummary,
    ReceiptProjection,
    ReconciliationSummary,
    StatementEntry,
)

ZERO = Decimal("0.00")


def _money(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


async def get_receipt(db: AsyncSession, payment_id: str) -> ReceiptProjection | None:
    """Return one immutable receipt without recalculating its allocation."""
    result = await db.execute(
        select(Payment)
        .options(
            selectinload(Payment.allocation),
            selectinload(Payment.recorded_by),
            selectinload(Payment.reversal),
            selectinload(Payment.reversal_of),
            selectinload(Payment.loan).selectinload(Loan.borrower),
        )
        .where(Payment.id == payment_id)
    )
    payment = result.scalar_one_or_none()
    if payment is None:
        return None
    allocation = payment.allocation
    reversal = payment.reversal if payment.entry_type == "Payment" else payment
    reason = (
        reversal.note
        if reversal is not None and reversal.entry_type == "Reversal"
        else None
    )
    return ReceiptProjection(
        receipt_number=f"RCPT-{payment.id.replace('-', '').upper()[:12]}",
        payment_id=payment.id,
        borrower=PartySummary(
            id=payment.loan.borrower.id,
            display_name=f"{payment.loan.borrower.first_name} {payment.loan.borrower.last_name}",
        ),
        loan=LoanResponse.model_validate(payment.loan),
        payment_date=payment.effective_date,
        recorded_by=payment.recorded_by.username,
        amount_received=payment.amount,
        interest_paid=allocation.applied_interest,
        principal_paid=allocation.applied_principal,
        penalty_paid=ZERO,
        unapplied_credit=allocation.unapplied_credit,
        remaining_balance=allocation.principal_after + allocation.interest_after,
        payment_method=None,
        request_id=payment.request_id,
        reversal_status=(
            "Reversal"
            if payment.entry_type == "Reversal"
            else "Reversed" if payment.reversal else "Original"
        ),
        reversal_reason=reason,
    )


async def get_statement(
    db: AsyncSession, loan_id: str
) -> LoanStatementProjection | None:
    """Build a reconciled statement solely from persisted schedule and ledger data."""
    result = await db.execute(
        select(Loan)
        .options(
            selectinload(Loan.borrower),
            selectinload(Loan.installments),
            selectinload(Loan.payments).selectinload(Payment.allocation),
            selectinload(Loan.payments).selectinload(Payment.reversal_of),
        )
        .where(Loan.id == loan_id)
    )
    loan = result.scalar_one_or_none()
    if loan is None:
        return None
    ledger = sorted(
        loan.payments, key=lambda item: (item.effective_date, item.created_at, item.id)
    )
    payments = [item for item in ledger if item.entry_type == "Payment"]
    reversals = [item for item in ledger if item.entry_type == "Reversal"]
    net_principal = sum((p.allocation.applied_principal for p in payments), ZERO) - sum(
        (p.allocation.applied_principal for p in reversals), ZERO
    )
    calculated = _money(loan.original_principal - net_principal)
    entries = [
        StatementEntry(
            payment_id=item.id,
            entry_type=item.entry_type,
            effective_date=item.effective_date,
            amount=item.amount,
            interest=item.allocation.applied_interest,
            principal=item.allocation.applied_principal,
            unapplied_credit=item.allocation.unapplied_credit,
            running_balance=item.allocation.principal_after
            + item.allocation.interest_after,
        )
        for item in ledger
    ]
    return LoanStatementProjection(
        generated_at=datetime.now(UTC),
        borrower=PartySummary(
            id=loan.borrower.id,
            display_name=f"{loan.borrower.first_name} {loan.borrower.last_name}",
        ),
        loan=LoanResponse.model_validate(loan),
        original_principal=loan.original_principal,
        current_principal=loan.outstanding_principal,
        interest_charged=sum(
            (item.expected_interest for item in loan.installments), ZERO
        ),
        interest_collected=sum((p.allocation.applied_interest for p in payments), ZERO)
        - sum((p.allocation.applied_interest for p in reversals), ZERO),
        penalties=ZERO,
        unapplied_credits=sum((p.allocation.unapplied_credit for p in payments), ZERO)
        - sum((p.allocation.unapplied_credit for p in reversals), ZERO),
        installment_schedule=[
            InstallmentResponse.model_validate(item) for item in loan.installments
        ],
        payment_history=[PaymentResponse.model_validate(item) for item in payments],
        reversal_history=[PaymentResponse.model_validate(item) for item in reversals],
        running_balance=entries,
        total_received=sum((p.amount for p in payments), ZERO),
        total_reversed=sum((p.amount for p in reversals), ZERO),
        reconciliation=ReconciliationSummary(
            calculated_principal=calculated,
            stored_principal=loan.outstanding_principal,
            difference=_money(calculated - loan.outstanding_principal),
            reconciled=calculated == _money(loan.outstanding_principal),
        ),
    )


async def dashboard(db: AsyncSession, as_of: date) -> DashboardProjection:
    """Aggregate current dashboard values with database-side decimal sums."""
    borrower_count = (
        await db.scalar(
            select(func.count())
            .select_from(Borrower)
            .where(Borrower.status != "Deleted")
        )
        or 0
    )
    loans = list(
        (
            await db.execute(
                select(Loan)
                .join(Loan.borrower)
                .options(selectinload(Loan.installments))
                .where(Borrower.status != "Deleted")
            )
        ).scalars()
    )
    due_rows = list(
        (
            await db.execute(
                select(Installment)
                .join(Installment.loan)
                .join(Loan.borrower)
                .where(Installment.due_date == as_of, Borrower.status != "Deleted")
            )
        ).scalars()
    )
    payments = list(
        (
            await db.execute(
                select(Payment)
                .join(Payment.loan)
                .join(Loan.borrower)
                .options(selectinload(Payment.allocation))
                .where(Payment.effective_date == as_of, Borrower.status != "Deleted")
            )
        ).scalars()
    )
    collectible = {"Active", "Overdue", "Defaulted"}
    due_today = sum(
        (
            max(item.expected_payment - item.paid_amount, ZERO)
            for item in due_rows
            if item.status not in {"Paid", "Cancelled"}
        ),
        ZERO,
    )
    cash = sum((p.amount for p in payments if p.entry_type == "Payment"), ZERO) - sum(
        (p.amount for p in payments if p.entry_type == "Reversal"), ZERO
    )
    progress = (
        ZERO
        if due_today + cash == ZERO
        else _money(cash * Decimal("100") / (due_today + cash))
    )
    overdue_ids = {
        loan.id
        for loan in loans
        if loan.status == "Defaulted"
        or any(
            item.due_date < as_of and item.status not in {"Paid", "Cancelled"}
            for item in loan.installments
        )
    }
    return DashboardProjection(
        as_of_date=as_of,
        total_borrowers=borrower_count,
        outstanding_balance=sum(
            (
                loan.outstanding_principal
                for loan in loans
                if loan.status in collectible
            ),
            ZERO,
        ),
        active_loans=sum(
            loan.status == "Active" and loan.id not in overdue_ids for loan in loans
        ),
        paid_loans=sum(loan.status == "Paid" for loan in loans),
        overdue_loans=len(overdue_ids),
        defaulted_loans=sum(loan.status == "Defaulted" for loan in loans),
        due_today=due_today,
        due_today_count=sum(
            item.status not in {"Paid", "Cancelled"} for item in due_rows
        ),
        cash_collected_today=cash,
        collection_progress=progress,
    )


async def financial_report(
    db: AsyncSession, date_from: date, date_to: date
) -> FinancialReportProjection:
    """Aggregate collections and portfolio risk for a closed date range."""
    loans = list(
        (
            await db.execute(
                select(Loan)
                .join(Loan.borrower)
                .options(selectinload(Loan.installments))
                .where(Borrower.status != "Deleted")
            )
        ).scalars()
    )
    payments = list(
        (
            await db.execute(
                select(Payment)
                .join(Payment.loan)
                .join(Loan.borrower)
                .options(
                    selectinload(Payment.allocation), selectinload(Payment.recorded_by)
                )
                .where(
                    Payment.effective_date.between(date_from, date_to),
                    Borrower.status != "Deleted",
                )
            )
        ).scalars()
    )

    def sign(payment: Payment) -> Decimal:
        return Decimal("-1") if payment.entry_type == "Reversal" else Decimal("1")

    outstanding = sum(
        (
            loan.outstanding_principal
            for loan in loans
            if loan.status in {"Active", "Overdue", "Defaulted"}
        ),
        ZERO,
    )
    overdue_loans = [
        loan
        for loan in loans
        if loan.status == "Defaulted"
        or any(
            item.due_date < date_to and item.status not in {"Paid", "Cancelled"}
            for item in loan.installments
        )
    ]
    at_risk = sum((loan.outstanding_principal for loan in overdue_loans), ZERO)
    aging = {"current": ZERO, "1-30": ZERO, "31-60": ZERO, "61-90": ZERO, "91+": ZERO}
    for loan in loans:
        past_due = [
            (date_to - item.due_date).days
            for item in loan.installments
            if item.due_date < date_to and item.status not in {"Paid", "Cancelled"}
        ]
        days = max(past_due, default=0)
        band = (
            "current"
            if days == 0
            else (
                "1-30"
                if days <= 30
                else "31-60" if days <= 60 else "61-90" if days <= 90 else "91+"
            )
        )
        aging[band] += loan.outstanding_principal
    collectors: dict[str, Decimal] = {}
    for payment in payments:
        collectors[payment.recorded_by.username] = (
            collectors.get(payment.recorded_by.username, ZERO)
            + sign(payment) * payment.amount
        )
    return FinancialReportProjection(
        date_from=date_from,
        date_to=date_to,
        outstanding_portfolio=outstanding,
        collections=sum((sign(p) * p.amount for p in payments), ZERO),
        interest_earned=sum(
            (sign(p) * p.allocation.applied_interest for p in payments), ZERO
        ),
        principal_collected=sum(
            (sign(p) * p.allocation.applied_principal for p in payments), ZERO
        ),
        unapplied_credits=sum(
            (sign(p) * p.allocation.unapplied_credit for p in payments), ZERO
        ),
        overdue_amount=at_risk,
        portfolio_at_risk=(
            ZERO
            if outstanding == ZERO
            else _money(at_risk * Decimal("100") / outstanding)
        ),
        overdue_loan_count=len(overdue_loans),
        loan_aging=aging,
        collector_performance=collectors,
    )
