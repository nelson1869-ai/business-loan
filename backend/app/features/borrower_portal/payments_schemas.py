"""Pydantic schemas for Borrower Portal Payments & Receipts API."""

from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict

from app.core.schemas.common import to_camel


class BorrowerPaymentListItemResponse(BaseModel):
    """Borrower-safe single payment record in history list."""

    id: str
    receipt_number: str
    effective_date: date
    amount: Decimal
    entry_type: str
    status: str
    created_at: datetime

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class BorrowerPaymentHistoryResponse(BaseModel):
    """Collection of payments for a borrower-owned loan."""

    items: list[BorrowerPaymentListItemResponse]
    total_count: int

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class BorrowerReceiptDetailResponse(BaseModel):
    """Immutable digital receipt overview with allocation breakdown."""

    receipt_number: str
    payment_id: str
    loan_id: str
    loan_reference: str
    payment_date: date
    amount_received: Decimal
    principal_paid: Decimal
    interest_paid: Decimal
    penalty_paid: Decimal
    unapplied_credit: Decimal
    remaining_balance: Decimal
    entry_type: str
    status: str
    recorded_at: datetime

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)
