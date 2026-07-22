"""Payment preview request and exact allocation response schemas."""

from datetime import date, datetime
from decimal import Decimal
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.common import to_camel


class PaymentPreviewRequest(BaseModel):
    """Candidate payment values accepted before an immutable confirmation."""

    amount: Decimal = Field(gt=0, max_digits=18, decimal_places=2)
    effective_date: date
    installment_id: str | None = Field(default=None, min_length=36, max_length=36)

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)

    @field_validator("amount", mode="before")
    @classmethod
    def reject_float_amount(cls, value: Any) -> Any:
        """Require exact JSON decimal strings or integers, never binary floats."""
        if isinstance(value, float):
            raise ValueError("must be sent as an exact decimal string")
        return value

    @field_validator("installment_id")
    @classmethod
    def validate_installment_id(cls, value: str | None) -> str | None:
        """Canonicalize an optional target installment UUID."""
        return None if value is None else str(UUID(value))


class PaymentCreate(PaymentPreviewRequest):
    """Immutable payment confirmation with a retry-safe request UUID."""

    request_id: str = Field(min_length=36, max_length=36)
    note: str | None = Field(default=None, max_length=500)

    @field_validator("request_id")
    @classmethod
    def validate_request_id(cls, value: str) -> str:
        return str(UUID(value))


class PaymentReversalCreate(BaseModel):
    """Reasoned, retry-safe request to reverse one complete payment."""

    request_id: str = Field(min_length=36, max_length=36)
    effective_date: date
    reason: str = Field(min_length=3, max_length=500)

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)

    @field_validator("request_id")
    @classmethod
    def validate_request_id(cls, value: str) -> str:
        return str(UUID(value))

    @field_validator("reason")
    @classmethod
    def normalize_reason(cls, value: str) -> str:
        reason = value.strip()
        if len(reason) < 3:
            raise ValueError("must contain at least 3 non-whitespace characters")
        return reason


class PaymentPreviewResponse(BaseModel):
    """Authoritative, non-persisted allocation shown before confirmation."""

    loan_id: str
    installment_id: str
    payment_amount: Decimal
    effective_date: date
    period_start_date: date
    accrual_start_date: date
    due_date: date
    scheduled_period_days: int
    elapsed_days: int
    days_early: int
    overdue_days: int
    periodic_rate: Decimal
    accrued_interest: Decimal
    carried_interest_before: Decimal
    total_interest_before: Decimal
    principal_before: Decimal
    applied_interest: Decimal
    applied_principal: Decimal
    unapplied_credit: Decimal
    interest_after: Decimal
    principal_after: Decimal
    scheduled_payment: Decimal
    amount_above_scheduled: Decimal
    next_period_interest: Decimal
    is_payoff: bool

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class PaymentAllocationResponse(BaseModel):
    """Persisted interest-first allocation snapshot."""

    interest_before: Decimal
    principal_before: Decimal
    applied_interest: Decimal
    applied_principal: Decimal
    unapplied_credit: Decimal
    interest_after: Decimal
    principal_after: Decimal
    overdue_days: int
    scheduled_period_days: int

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True, from_attributes=True)


class PaymentResponse(BaseModel):
    """One immutable payment ledger entry and its allocation."""

    id: str
    request_id: str
    loan_id: str
    installment_id: str | None
    recorded_by_user_id: str
    reversal_of_payment_id: str | None
    entry_type: Literal["Payment", "Reversal"]
    amount: Decimal
    effective_date: date
    note: str | None
    created_at: datetime
    allocation: PaymentAllocationResponse

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True, from_attributes=True)


class PaymentReversalResponse(PaymentResponse):
    """A reversal ledger entry linked permanently to its original payment."""

    reversal_of_payment_id: str
    entry_type: Literal["Reversal"]


class PaymentPage(BaseModel):
    """Backward-compatible paginated payment collection envelope."""

    items: list[PaymentResponse]
    total: int
    offset: int
    limit: int

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)
