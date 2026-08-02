"""Pydantic schemas for the borrower portal dashboard (/api/v1/client/dashboard)."""

from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class BorrowerSummaryInfo(BaseModel):
    """Basic identity information for the authenticated borrower."""

    id: str
    first_name: str = Field(..., alias="firstName")
    last_name: str = Field(..., alias="lastName")

    model_config = ConfigDict(populate_by_name=True)


class DashboardSummary(BaseModel):
    """Aggregate financial metrics and loan status overview."""

    active_loan_count: int = Field(..., alias="activeLoanCount")
    total_outstanding_balance: Decimal = Field(..., alias="totalOutstandingBalance")
    next_payment_amount: Decimal = Field(..., alias="nextPaymentAmount")
    next_due_date: date | None = Field(None, alias="nextDueDate")
    overdue_amount: Decimal = Field(..., alias="overdueAmount")
    loan_status: str = Field(..., alias="loanStatus")
    payment_status: str = Field(..., alias="paymentStatus")

    model_config = ConfigDict(populate_by_name=True)


class DashboardRecentPayment(BaseModel):
    """Summary of the borrower's most recent payment transaction."""

    id: str
    amount: Decimal
    effective_date: date = Field(..., alias="effectiveDate")
    entry_type: str = Field(..., alias="entryType")
    receipt_number: str | None = Field(None, alias="receiptNumber")

    model_config = ConfigDict(populate_by_name=True)


class BorrowerDashboardResponse(BaseModel):
    """Complete backend response for GET /api/v1/client/dashboard."""

    borrower: BorrowerSummaryInfo
    summary: DashboardSummary
    recent_payment: DashboardRecentPayment | None = Field(None, alias="recentPayment")
    last_updated: datetime = Field(..., alias="lastUpdated")

    model_config = ConfigDict(populate_by_name=True)
