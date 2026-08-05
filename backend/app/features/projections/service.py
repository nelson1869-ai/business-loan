"""Ledger-backed receipt, statement, dashboard, and report projections."""

from dataclasses import dataclass
from datetime import UTC, date, datetime
from decimal import ROUND_HALF_UP, Decimal

from sqlalchemy import func, inspect, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.features.borrowers.models import Borrower
from app.features.loans.models import Installment, Loan
from app.features.loans.schemas import InstallmentResponse, LoanResponse
from app.features.payments.models import Payment
from app.features.payments.schemas import PaymentResponse
from app.features.projections.schemas import (
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


def _overdue_installment_amount(loans: list[Loan], as_of: date) -> Decimal:
    """Return unpaid scheduled amounts strictly overdue at the snapshot date."""
    return sum(
        (
            max(item.expected_payment - item.paid_amount, ZERO)
            for loan in loans
            for item in loan.installments
            if item.due_date < as_of and item.status not in {"Paid", "Cancelled"}
        ),
        ZERO,
    )


def format_payment_frequency(payments_per_month: int) -> str:
    """Return standard payment frequency string derived from payments_per_month."""
    mapping = {
        1: "monthly",
        2: "semi_monthly",
        4: "weekly",
        30: "daily",
    }
    return mapping.get(payments_per_month, f"{payments_per_month}_per_month")


def get_public_loan_reference(loan: Loan) -> str:
    """Return the borrower-safe display reference for a loan.

    Uses loan.loan_reference if present and non-empty. Otherwise, formats
    an explicit loan reference string (e.g. 'LN-2026-000123').
    Never exposes internal idempotency request_id or raw database UUIDs.
    """
    if hasattr(loan, "loan_reference") and getattr(loan, "loan_reference", None):
        return getattr(loan, "loan_reference")
    ref_year = (
        loan.start_date.year
        if loan.start_date
        else (loan.created_at.year if loan.created_at else 2026)
    )
    clean_id = loan.id.replace("-", "").upper()
    return f"LN-{ref_year}-{clean_id[:6]}"


def get_next_installment_priority(
    loan: Loan, as_of: date
) -> tuple[Installment | None, Decimal, date | None, bool]:
    """Select the next required payment installment for a loan according to business priority.

    Priority Policy:
    1. Earliest unpaid OVERDUE installment (due_date < as_of)
    2. Earliest unpaid UPCOMING installment (due_date >= as_of)

    Returns tuple of (next_installment, next_payment_amount, next_due_date, is_overdue).
    """
    if not loan.installments:
        return None, ZERO, None, False

    all_unpaid = sorted(
        [
            inst
            for inst in loan.installments
            if inst.status not in {"Paid", "Cancelled"}
        ],
        key=lambda i: (i.due_date, i.installment_number),
    )

    overdue_insts = [inst for inst in all_unpaid if inst.due_date < as_of]
    upcoming_insts = [inst for inst in all_unpaid if inst.due_date >= as_of]

    # Business policy: Overdue unpaid installments take priority as the next required payment
    next_inst = (
        overdue_insts[0]
        if overdue_insts
        else (upcoming_insts[0] if upcoming_insts else None)
    )

    overdue_total = sum(
        (max(inst.expected_payment - inst.paid_amount, ZERO) for inst in overdue_insts),
        ZERO,
    )
    is_overdue = overdue_total > ZERO or loan.status in {"Overdue", "Defaulted"}

    if next_inst is None:
        return None, ZERO, None, is_overdue

    next_amount = max(next_inst.expected_payment - next_inst.paid_amount, ZERO)
    return next_inst, _money(next_amount), next_inst.due_date, is_overdue


@dataclass(frozen=True)
class LoanFinancialProjection:
    """Authoritative, strongly-typed financial projection for a loan."""

    principal_amount: Decimal
    interest_amount: Decimal
    fees_amount: Decimal
    total_repayable: Decimal
    amount_paid: Decimal
    outstanding_balance: Decimal
    overdue_amount: Decimal


def _is_loaded(instance: object, attr_name: str) -> bool:
    """Return True if relationship or attribute is loaded in memory without triggering lazy-load."""
    try:
        ins = inspect(instance)
        return ins is not None and hasattr(ins, "dict") and attr_name in ins.dict
    except Exception:
        return False


async def fetch_loan_installments(db: AsyncSession, loan: Loan) -> list[Installment]:
    """Retrieve installments for loan from session cache, loaded relationship, or DB query."""
    if _is_loaded(loan, "installments") and loan.installments is not None:
        return list(loan.installments)
    result = await db.execute(
        select(Installment)
        .where(Installment.loan_id == loan.id)
        .order_by(Installment.due_date, Installment.installment_number)
    )
    return list(result.scalars().all())


async def fetch_loan_payments(db: AsyncSession, loan: Loan) -> list[Payment]:
    """Retrieve payment ledger entries for loan from session cache, loaded relationship, or DB query."""
    if _is_loaded(loan, "payments") and loan.payments is not None:
        return list(loan.payments)
    result = await db.execute(
        select(Payment).where(Payment.loan_id == loan.id).order_by(Payment.created_at)
    )
    return list(result.scalars().all())


async def build_loan_financial_projection(
    db: AsyncSession, loan: Loan, as_of: date
) -> LoanFinancialProjection:
    """Build authoritative financial projection for a loan querying DB when relationships are unloaded."""
    insts = await fetch_loan_installments(db, loan)
    pmts = await fetch_loan_payments(db, loan)

    total_interest = sum((inst.expected_interest for inst in insts), ZERO)
    total_repayable = _money(loan.original_principal + total_interest)

    if pmts:
        effective_payments = [
            p
            for p in pmts
            if p.entry_type == "Payment"
            and getattr(p, "status", "Posted") not in {"Cancelled", "Failed", "Pending"}
        ]
        effective_reversals = [
            p
            for p in pmts
            if p.entry_type == "Reversal"
            and getattr(p, "status", "Posted") not in {"Cancelled", "Failed", "Pending"}
        ]
        net_paid = sum((p.amount for p in effective_payments), ZERO) - sum(
            (p.amount for p in effective_reversals), ZERO
        )
    else:
        net_paid = sum((inst.paid_amount for inst in insts), ZERO)

    amount_paid = max(_money(net_paid), ZERO)
    outstanding_balance = _money(loan.outstanding_principal)

    overdue_amount = sum(
        (
            max(inst.expected_payment - inst.paid_amount, ZERO)
            for inst in insts
            if inst.due_date < as_of and inst.status not in {"Paid", "Cancelled"}
        ),
        ZERO,
    )

    return LoanFinancialProjection(
        principal_amount=_money(loan.original_principal),
        interest_amount=_money(total_interest),
        fees_amount=ZERO,
        total_repayable=total_repayable,
        amount_paid=amount_paid,
        outstanding_balance=outstanding_balance,
        overdue_amount=_money(overdue_amount),
    )


async def build_loan_last_activity_timestamp(db: AsyncSession, loan: Loan) -> datetime:
    """Return latest financial activity timestamp querying DB when relationships are unloaded."""
    candidates: list[datetime] = []

    updated_at = getattr(loan, "updated_at", None)
    if isinstance(updated_at, datetime):
        candidates.append(updated_at)
    if getattr(loan, "created_at", None):
        candidates.append(loan.created_at)

    pmts = await fetch_loan_payments(db, loan)
    for p in pmts:
        if getattr(p, "created_at", None):
            candidates.append(p.created_at)
        elif getattr(p, "effective_date", None):
            dt = datetime.combine(p.effective_date, datetime.min.time()).replace(
                tzinfo=UTC
            )
            candidates.append(dt)

    insts = await fetch_loan_installments(db, loan)
    for inst in insts:
        inst_updated_at = getattr(inst, "updated_at", None)
        if isinstance(inst_updated_at, datetime):
            candidates.append(inst_updated_at)

    if not candidates:
        return datetime.now(UTC)

    return max(candidates)


def get_loan_last_activity_timestamp(loan: Loan) -> datetime:
    """Return latest financial activity timestamp for eager-loaded loan objects."""
    candidates: list[datetime] = []

    updated_at = getattr(loan, "updated_at", None)
    if isinstance(updated_at, datetime):
        candidates.append(updated_at)
    if getattr(loan, "created_at", None):
        candidates.append(loan.created_at)

    if _is_loaded(loan, "payments") and loan.payments:
        for p in loan.payments:
            if getattr(p, "created_at", None):
                candidates.append(p.created_at)
            elif getattr(p, "effective_date", None):
                dt = datetime.combine(p.effective_date, datetime.min.time()).replace(
                    tzinfo=UTC
                )
                candidates.append(dt)

    if _is_loaded(loan, "installments") and loan.installments:
        for inst in loan.installments:
            inst_updated_at = getattr(inst, "updated_at", None)
            if isinstance(inst_updated_at, datetime):
                candidates.append(inst_updated_at)

    if not candidates:
        return datetime.now(UTC)

    return max(candidates)


def compute_loan_financial_summary(loan: Loan, as_of: date) -> LoanFinancialProjection:
    """Synchronous calculation helper for eager-loaded loan objects."""
    insts = (
        loan.installments
        if _is_loaded(loan, "installments") and loan.installments
        else []
    )
    pmts = loan.payments if _is_loaded(loan, "payments") and loan.payments else []

    total_interest = sum((inst.expected_interest for inst in insts), ZERO)
    total_repayable = _money(loan.original_principal + total_interest)

    if pmts:
        effective_payments = [
            p
            for p in pmts
            if p.entry_type == "Payment"
            and getattr(p, "status", "Posted") not in {"Cancelled", "Failed", "Pending"}
        ]
        effective_reversals = [
            p
            for p in pmts
            if p.entry_type == "Reversal"
            and getattr(p, "status", "Posted") not in {"Cancelled", "Failed", "Pending"}
        ]
        net_paid = sum((p.amount for p in effective_payments), ZERO) - sum(
            (p.amount for p in effective_reversals), ZERO
        )
    else:
        net_paid = sum((inst.paid_amount for inst in insts), ZERO)

    amount_paid = max(_money(net_paid), ZERO)
    outstanding_balance = _money(loan.outstanding_principal)

    overdue_amount = sum(
        (
            max(inst.expected_payment - inst.paid_amount, ZERO)
            for inst in insts
            if inst.due_date < as_of and inst.status not in {"Paid", "Cancelled"}
        ),
        ZERO,
    )

    return LoanFinancialProjection(
        principal_amount=_money(loan.original_principal),
        interest_amount=_money(total_interest),
        fees_amount=ZERO,
        total_repayable=total_repayable,
        amount_paid=amount_paid,
        outstanding_balance=outstanding_balance,
        overdue_amount=_money(overdue_amount),
    )


def compute_loan_financial_summary_dict(loan: Loan, as_of: date) -> dict[str, Decimal]:
    """Deprecated dict wrapper preserved for backward compatibility."""
    proj = compute_loan_financial_summary(loan, as_of)
    return {
        "principal_amount": proj.principal_amount,
        "interest_amount": proj.interest_amount,
        "fees_amount": proj.fees_amount,
        "total_repayable": proj.total_repayable,
        "amount_paid": proj.amount_paid,
        "outstanding_balance": proj.outstanding_balance,
        "overdue_amount": proj.overdue_amount,
    }


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
            else "Reversed"
            if payment.reversal
            else "Original"
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
                else "31-60"
                if days <= 60
                else "61-90"
                if days <= 90
                else "91+"
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
        overdue_amount=_overdue_installment_amount(loans, date_to),
        portfolio_at_risk=(
            ZERO
            if outstanding == ZERO
            else _money(at_risk * Decimal("100") / outstanding)
        ),
        overdue_loan_count=len(overdue_loans),
        loan_aging=aging,
        collector_performance=collectors,
    )
