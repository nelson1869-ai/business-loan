"""Pydantic schemas for Payment Receipts, Verification, and Notifications."""

from datetime import date, datetime
from decimal import Decimal
from pydantic import BaseModel, ConfigDict, Field


class PaymentReceiptResponse(BaseModel):
    """Full deterministic receipt snapshot response model."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    payment_id: str
    receipt_number: str
    receipt_status: str
    borrower_id: str
    borrower_name: str
    borrower_account_ref: str
    loan_id: str
    loan_reference: str
    payment_date: date
    payment_time: datetime
    effective_date: date
    payment_method: str
    external_reference: str | None = None
    amount_received: Decimal
    balance_before_payment: Decimal
    principal_applied: Decimal
    interest_applied: Decimal
    penalty_applied: Decimal
    fees_applied: Decimal
    unapplied_credit: Decimal
    remaining_principal: Decimal
    outstanding_interest: Decimal
    overdue_amount: Decimal
    total_outstanding_amount: Decimal
    next_payment_amount: Decimal | None = None
    next_due_date: date | None = None
    loan_status_after: str
    recorded_by_name: str
    verification_token: str
    receipt_version: int
    reversal_payment_id: str | None = None
    reversal_reason: str | None = None
    reversal_at: datetime | None = None
    deterministic_explanation: str
    ai_explanation: str | None = None
    ai_explanation_model: str | None = None
    created_at: datetime


class PublicReceiptVerificationResponse(BaseModel):
    """Minimal non-PII verification response schema for public QR scanner."""

    is_valid: bool = True
    receipt_number: str
    receipt_status: str
    amount_received: Decimal
    payment_date: date
    effective_date: date
    business_identity: str = "Lending Nelson"
    verified_at: datetime


class AIExplanationResponse(BaseModel):
    """Response model for AI explanation with fallback indicator."""

    receipt_id: str
    explanation: str
    is_ai_generated: bool
    notice: str = "AI-generated explanation. The official receipt figures remain the authoritative record."


class BorrowerNotificationResponse(BaseModel):
    """In-app notification response model."""

    model_config = ConfigDict(from_attributes=True)

    id: str
    borrower_id: str
    title: str
    message: str
    notification_type: str
    metadata_json: str | None = None
    is_read: bool
    created_at: datetime
