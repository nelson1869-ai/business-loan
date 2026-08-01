"""Versioned backend-to-n8n event envelope & domain schemas."""

import uuid
from datetime import datetime, timezone
from typing import Generic, TypeVar

from pydantic import BaseModel, Field

T = TypeVar("T")


class EventActor(BaseModel):
    """User or system identity originating the event."""

    id: str = Field(..., description="User ID or system actor identifier.")
    role: str = Field(
        ..., description="Role of the actor (e.g., officer, admin, system)."
    )


class EventEntity(BaseModel):
    """Domain entity reference."""

    type: str = Field(
        ..., description="Entity type (e.g., loan, payment, borrower, collection_task)."
    )
    id: str = Field(..., description="Unique entity identifier.")


class DomainEventEnvelope(BaseModel, Generic[T]):
    """Standardized versioned event envelope sent from FastAPI backend to n8n webhooks."""

    eventId: str = Field(
        default_factory=lambda: str(uuid.uuid4()),
        description="Unique UUID for this event occurrence.",
    )
    eventType: str = Field(
        ..., description="Domain event type (e.g., payment.received)."
    )
    eventVersion: int = Field(
        default=1, description="Schema version of the event payload."
    )
    occurredAt: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat(),
        description="ISO 8601 UTC timestamp when event occurred.",
    )
    businessTimezone: str = Field(
        default="Asia/Manila",
        description="Primary business operating timezone.",
    )
    source: str = Field(
        default="lending-nelson-api",
        description="Event publisher origin service.",
    )
    correlationId: str = Field(
        default_factory=lambda: str(uuid.uuid4()),
        description="Trace correlation ID across requests.",
    )
    idempotencyKey: str = Field(
        ...,
        description="Stable key ensuring target workflows process event once.",
    )
    tenantId: str | None = Field(
        default=None, description="Optional multi-tenant organization ID."
    )
    actor: EventActor = Field(
        ..., description="Actor identity who performed the action."
    )
    entity: EventEntity = Field(..., description="Primary domain entity target.")
    data: T = Field(..., description="Structured domain event payload.")


class PaymentReceivedData(BaseModel):
    payment_id: str
    loan_id: str
    borrower_id: str
    amount_paid: str
    remaining_balance: str
    effective_date: str
    note: str | None = None
    borrower_name: str | None = None
    borrower_phone: str | None = None


class PaymentReversedData(BaseModel):
    payment_id: str
    loan_id: str
    borrower_id: str
    reversal_amount: str
    reason: str
    reinstated_balance: str


class LoanLifecycleData(BaseModel):
    loan_id: str
    borrower_id: str
    request_id: str | None = None
    original_principal: str
    outstanding_principal: str
    status: str
    term_months: int
    created_by: str | None = None
    borrower_name: str | None = None
    borrower_phone: str | None = None


class InstallmentDueData(BaseModel):
    installment_id: str
    loan_id: str
    borrower_id: str
    installment_number: int
    due_date: str
    amount_due: str
    days_overdue: int = 0
    reminder_window: str  # '3_days_before', 'due_today', '1_day_overdue', etc.
    borrower_name: str | None = None
    borrower_phone: str | None = None


class CollectionTaskData(BaseModel):
    task_id: str
    loan_id: str
    borrower_id: str
    assigned_user_id: str | None = None
    task_type: str
    status: str
    due_date: str | None = None
    notes: str | None = None


class SyncItemFailedData(BaseModel):
    transaction_uuid: str
    entity_type: str
    entity_id: str | None = None
    attempt_count: int
    error_message: str
    client_device_id: str | None = None


__all__ = [
    "CollectionTaskData",
    "DomainEventEnvelope",
    "EventActor",
    "EventEntity",
    "InstallmentDueData",
    "LoanLifecycleData",
    "PaymentReceivedData",
    "PaymentReversedData",
    "SyncItemFailedData",
]
