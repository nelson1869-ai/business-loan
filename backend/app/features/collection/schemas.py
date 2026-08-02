"""Collection follow-up request and response schemas."""

from datetime import date, datetime
from decimal import Decimal
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.core.schemas.common import to_camel

TaskType = Literal["Call", "Visit", "Message", "PromiseToPay", "General"]
TaskPriority = Literal["Low", "Normal", "High", "Critical"]
TaskStatus = Literal["Pending", "Completed", "Cancelled"]


class CollectionSessionCreate(BaseModel):
    collector_user_id: str
    opening_cash: Decimal = Field(ge=0, max_digits=18, decimal_places=2)

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class CollectionSessionSubmit(BaseModel):
    actual_cash: Decimal = Field(ge=0, max_digits=18, decimal_places=2)
    variance_reason: str | None = Field(default=None, max_length=500)

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class CollectionSessionDecision(BaseModel):
    reason: str = Field(min_length=3, max_length=500)


class CollectionSessionDeposit(BaseModel):
    amount: Decimal = Field(gt=0, max_digits=18, decimal_places=2)
    reference: str = Field(min_length=1, max_length=120)


class CollectionSessionResponse(BaseModel):
    id: str
    collector_user_id: str
    opened_by_user_id: str
    opening_cash: Decimal
    expected_cash: Decimal
    actual_cash: Decimal
    cash_variance: Decimal
    variance_reason: str | None
    deposit_amount: Decimal
    deposit_reference: str | None
    status: str
    reviewer_user_id: str | None
    reviewed_at: datetime | None
    reconciled_at: datetime | None
    deposited_at: datetime | None
    closed_at: datetime | None
    created_at: datetime

    model_config = ConfigDict(
        from_attributes=True, alias_generator=to_camel, populate_by_name=True
    )


class CollectionTaskCreate(BaseModel):
    id: UUID | None = None
    borrower_id: str
    loan_id: str
    installment_number: int | None = Field(default=None, ge=1)
    task_type: TaskType
    priority: TaskPriority = "Normal"
    description: str | None = Field(default=None, max_length=2000)
    due_at: datetime
    assigned_to_user_id: str | None = None
    promised_amount: Decimal | None = Field(
        default=None, gt=0, max_digits=18, decimal_places=2
    )
    promise_date: date | None = None

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class CollectionTaskComplete(BaseModel):
    completion_note: str | None = Field(default=None, max_length=2000)

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class PromiseStatusUpdate(BaseModel):
    promise_status: Literal["Kept", "Broken", "Cancelled"]
    linked_payment_id: str | None = None

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class CollectionTaskResponse(BaseModel):
    id: str
    borrower_id: str
    loan_id: str
    installment_number: int | None
    task_type: str
    priority: str
    description: str | None
    status: str
    due_at: datetime
    created_by_user_id: str
    assigned_to_user_id: str
    completed_by_user_id: str | None
    completed_at: datetime | None
    completion_note: str | None
    created_at: datetime
    promised_amount: Decimal | None
    promise_date: date | None
    promise_status: str | None
    linked_payment_id: str | None

    model_config = ConfigDict(
        alias_generator=to_camel, populate_by_name=True, from_attributes=True
    )
