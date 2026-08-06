"""Loan account and installment request/response schemas."""

from datetime import date, datetime
from decimal import Decimal
from typing import Any, Literal, Self
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.core.schemas.common import to_camel

LoanStatus = Literal[
    "Draft", "Active", "Paid", "Overdue", "Defaulted", "Cancelled", "WrittenOff"
]
InstallmentStatus = Literal[
    "Scheduled",
    "PartiallyPaid",
    "Paid",
    "Overdue",
    "Cancelled",
]
CalculationMethod = Literal["fixed_periodic_reducing_balance"]
LoanWorkflowAction = Literal[
    "approve", "disburse", "activate", "approve_and_activate", "complete", "default", "cancel", "close"
]


class LoanCreate(BaseModel):
    """Lender-approved terms accepted when creating a loan account."""

    borrower_id: str = Field(min_length=36, max_length=36)
    request_id: str | None = Field(default=None, min_length=36, max_length=36)
    policy_version_id: str | None = Field(default=None, min_length=36, max_length=36)
    original_principal: Decimal = Field(gt=0, max_digits=18, decimal_places=2)
    monthly_rate: Decimal = Field(ge=0, max_digits=10, decimal_places=8)
    term_months: int = Field(gt=0, le=600)
    payments_per_month: int = Field(gt=0, le=31)
    start_date: date
    first_due_date: date
    calculation_method: CalculationMethod = "fixed_periodic_reducing_balance"

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)

    @field_validator("original_principal", "monthly_rate", mode="before")
    @classmethod
    def reject_float_money_and_rates(cls, value: Any) -> Any:
        """Require JSON decimal strings or integers instead of binary floats."""
        if isinstance(value, float):
            raise ValueError("must be sent as an exact decimal string")
        return value

    @field_validator("borrower_id", "request_id", "policy_version_id")
    @classmethod
    def validate_uuid(cls, value: str | None) -> str | None:
        """Require canonical UUID strings for borrower and request IDs."""
        if value is None:
            return None
        return str(UUID(value))

    @model_validator(mode="after")
    def validate_dates(self) -> Self:
        """Require the first installment to occur after loan disbursement."""
        if self.first_due_date <= self.start_date:
            raise ValueError("firstDueDate must be after startDate")
        return self

    @property
    def number_of_payments(self) -> int:
        """Return the agreed term multiplied by payments per month."""
        return self.term_months * self.payments_per_month


class LoanQuoteRequest(BaseModel):
    """Non-persistent loan terms submitted for an indicative quote."""

    original_principal: Decimal = Field(gt=0, max_digits=18, decimal_places=2)
    monthly_rate: Decimal = Field(ge=0, max_digits=10, decimal_places=8)
    term_months: int = Field(gt=0, le=600)
    payments_per_month: int = Field(gt=0, le=31)
    first_due_date: date
    calculation_method: CalculationMethod = "fixed_periodic_reducing_balance"

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)

    @field_validator("original_principal", "monthly_rate", mode="before")
    @classmethod
    def reject_float_money_and_rates(cls, value: Any) -> Any:
        """Require exact decimal JSON values rather than binary floats."""
        if isinstance(value, float):
            raise ValueError("must be sent as an exact decimal string")
        return value

    @property
    def number_of_payments(self) -> int:
        """Return the quoted number of installments."""
        return self.term_months * self.payments_per_month


class LoanQuoteInstallment(BaseModel):
    """One calculated installment in a non-persistent quote."""

    installment_number: int
    due_date: date
    payment_amount: Decimal
    interest_amount: Decimal
    principal_amount: Decimal
    remaining_principal: Decimal

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class LoanQuoteResponse(BaseModel):
    """Calculated totals and schedule that do not create database records."""

    original_principal: Decimal
    monthly_rate: Decimal
    term_months: int
    payments_per_month: int
    number_of_payments: int
    regular_payment_amount: Decimal
    total_interest: Decimal
    total_repayment: Decimal
    final_due_date: date
    calculation_method: CalculationMethod
    installments: list[LoanQuoteInstallment]

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class InstallmentResponse(BaseModel):
    """One persisted expected installment returned to Flutter."""

    id: str
    loan_id: str
    installment_number: int
    due_date: date
    expected_payment: Decimal
    expected_interest: Decimal
    expected_principal: Decimal
    expected_remaining_principal: Decimal
    paid_amount: Decimal
    status: InstallmentStatus
    created_at: datetime

    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        from_attributes=True,
    )


class LoanResponse(BaseModel):
    """A persisted loan account without its full installment collection."""

    id: str
    request_id: str
    borrower_id: str
    created_by_user_id: str
    policy_version_id: str | None = None
    policy_snapshot: dict[str, Any] = Field(default_factory=dict)
    original_principal: Decimal
    outstanding_principal: Decimal
    monthly_rate: Decimal
    term_months: int
    payments_per_month: int
    number_of_payments: int
    regular_payment_amount: Decimal
    calculation_method: CalculationMethod
    start_date: date
    first_due_date: date
    final_due_date: date
    status: LoanStatus
    approved_by_user_id: str | None = None
    approved_at: datetime | None = None
    disbursed_by_user_id: str | None = None
    disbursed_at: datetime | None = None
    activated_at: datetime | None = None
    created_at: datetime

    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        from_attributes=True,
    )

    @field_validator("policy_snapshot", mode="before")
    @classmethod
    def normalize_legacy_policy_snapshot(cls, value: Any) -> dict[str, Any]:
        """Tolerate pre-migration and mocked loan objects during rolling upgrades."""
        return value if isinstance(value, dict) else {}


class LoanDetailResponse(LoanResponse):
    """A loan account returned together with its ordered installments.

    [unapplied_credit] is the net advance credit held across all active
    payment allocations that has not yet been forwarded to a future
    installment.  Flutter uses this to suppress the Due-Installment
    quick-fill button when the credit already covers the next payment.
    """

    installments: list[InstallmentResponse]
    unapplied_credit: Decimal = Decimal("0.00")


class LoanPage(BaseModel):
    """Backward-compatible paginated loan collection envelope."""

    items: list[LoanResponse]
    total: int
    offset: int
    limit: int

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class LoanWorkflowResponse(BaseModel):
    """Result of a validated persisted lifecycle command."""

    loan_id: str
    action: LoanWorkflowAction
    status: LoanStatus
    occurred_at: datetime

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class LoanExplanationResponse(BaseModel):
    """A read-only, AI-generated explanation of deterministic loan figures."""

    summary: str = Field(min_length=1, max_length=1200)
    key_points: list[str] = Field(min_length=1, max_length=5)
    generated_at: datetime
    model: str
    disclaimer: str = (
        "AI-generated explanation. Verify against the official loan schedule."
    )

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)
