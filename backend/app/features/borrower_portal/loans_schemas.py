"""Pydantic schemas for Borrower Portal Loans API (GET /api/v1/client/loans)."""

from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.core.schemas.common import to_camel


class BorrowerLoanListItem(BaseModel):
    """Borrower-safe summary item for loan list views."""

    id: str
    loan_reference: str
    status: str
    principal_amount: Decimal
    total_repayable: Decimal
    amount_paid: Decimal
    outstanding_balance: Decimal
    installment_amount: Decimal
    payment_frequency: str
    start_date: date
    maturity_date: date
    next_due_date: date | None = None
    next_payment_amount: Decimal = Decimal("0.00")
    is_overdue: bool = False
    overdue_amount: Decimal = Decimal("0.00")
    updated_at: datetime

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class BorrowerLoanListResponse(BaseModel):
    """Paginated collection of borrower-owned loans."""

    items: list[BorrowerLoanListItem]
    total: int = Field(ge=0)
    offset: int = Field(ge=0)
    limit: int = Field(ge=1, le=100)

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class BorrowerLoanFinancialSummary(BaseModel):
    """Financial breakdown of a borrower loan."""

    principal_amount: Decimal
    interest_amount: Decimal
    fees_amount: Decimal = Decimal("0.00")
    total_repayable: Decimal
    amount_paid: Decimal
    outstanding_balance: Decimal
    overdue_amount: Decimal = Decimal("0.00")

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class BorrowerLoanTerms(BaseModel):
    """Agreed terms of a borrower loan."""

    payment_frequency: str
    installment_count: int
    installment_amount: Decimal
    interest_rate: Decimal
    start_date: date
    maturity_date: date

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class BorrowerNextInstallment(BaseModel):
    """Next expected installment preview for a borrower loan."""

    installment_number: int
    due_date: date
    amount_due: Decimal
    amount_paid: Decimal
    remaining_amount: Decimal
    status: str

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class BorrowerLoanDetailResponse(BaseModel):
    """Detailed read-only overview of a borrower loan."""

    id: str
    loan_reference: str
    status: str
    financial_summary: BorrowerLoanFinancialSummary
    terms: BorrowerLoanTerms
    next_installment: BorrowerNextInstallment | None = None
    last_updated: datetime

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)
