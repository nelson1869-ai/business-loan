"""Read-only financial projections derived from the persisted ledger."""

from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict

from app.schemas.common import to_camel
from app.schemas.loan import InstallmentResponse, LoanResponse
from app.schemas.payment import PaymentResponse


class ProjectionModel(BaseModel):
    """Camel-case base for Flutter projection responses."""

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class PartySummary(ProjectionModel):
    """Minimal borrower identity required by a financial document."""

    id: str
    display_name: str


class ReceiptProjection(ProjectionModel):
    """Immutable receipt view over one payment ledger entry."""

    receipt_number: str
    payment_id: str
    borrower: PartySummary
    loan: LoanResponse
    payment_date: date
    recorded_by: str
    amount_received: Decimal
    interest_paid: Decimal
    principal_paid: Decimal
    penalty_paid: Decimal
    unapplied_credit: Decimal
    remaining_balance: Decimal
    payment_method: str | None
    request_id: str
    reversal_status: str
    reversal_reason: str | None


class StatementEntry(ProjectionModel):
    """One signed ledger movement and its resulting balance."""

    payment_id: str
    entry_type: str
    effective_date: date
    amount: Decimal
    interest: Decimal
    principal: Decimal
    unapplied_credit: Decimal
    running_balance: Decimal


class ReconciliationSummary(ProjectionModel):
    """Proof that ledger principal agrees with the loan snapshot."""

    calculated_principal: Decimal
    stored_principal: Decimal
    difference: Decimal
    reconciled: bool


class LoanStatementProjection(ProjectionModel):
    """Complete loan statement generated from schedules and ledger entries."""

    generated_at: datetime
    borrower: PartySummary
    loan: LoanResponse
    original_principal: Decimal
    current_principal: Decimal
    interest_charged: Decimal
    interest_collected: Decimal
    penalties: Decimal
    unapplied_credits: Decimal
    installment_schedule: list[InstallmentResponse]
    payment_history: list[PaymentResponse]
    reversal_history: list[PaymentResponse]
    running_balance: list[StatementEntry]
    total_received: Decimal
    total_reversed: Decimal
    reconciliation: ReconciliationSummary


class DashboardProjection(ProjectionModel):
    """Backend-owned portfolio metrics optimized for Flutter dashboards."""

    as_of_date: date
    total_borrowers: int
    outstanding_balance: Decimal
    active_loans: int
    paid_loans: int
    overdue_loans: int
    defaulted_loans: int
    due_today: Decimal
    due_today_count: int
    cash_collected_today: Decimal
    collection_progress: Decimal


class FinancialReportProjection(ProjectionModel):
    """Reusable financial report totals for a requested date window."""

    date_from: date
    date_to: date
    outstanding_portfolio: Decimal
    collections: Decimal
    interest_earned: Decimal
    principal_collected: Decimal
    unapplied_credits: Decimal
    overdue_amount: Decimal
    portfolio_at_risk: Decimal
    overdue_loan_count: int
    loan_aging: dict[str, Decimal]
    collector_performance: dict[str, Decimal]
