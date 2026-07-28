"""Contracts for the read-only administrative business assistant."""

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.common import to_camel


class AdminAssistantRequest(BaseModel):
    message: str = Field(min_length=2, max_length=500)
    selected_borrower_id: str | None = Field(default=None, min_length=36, max_length=36)
    offset: int = Field(default=0, ge=0, le=10_000)

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


AssistantIntent = Literal[
    "collections_this_month",
    "unpaid_today",
    "due_tomorrow",
    "overdue",
    "portfolio_summary",
    "borrower_directory",
    "borrower_principal",
    "borrower_balance",
    "borrower_next_payment",
    "borrower_overdue_installments",
    "borrower_payment_history",
    "borrower_loan_summary",
    "help",
]

AIStatus = Literal[
    "skipped",
    "enhanced",
    "disabled",
    "unavailable",
    "rate_limited",
    "cooldown",
    "invalid_response",
]


class AdminAssistantRecord(BaseModel):
    borrower_id: str
    borrower_name: str
    loan_id: str = ""
    amount_due: str = "0.00"
    due_date: date | None = None
    status: str
    record_type: Literal["borrower", "installment", "payment"] = "installment"
    amount_paid: str | None = None
    effective_date: date | None = None

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class BorrowerClarificationOption(BaseModel):
    borrower_id: str
    display_name: str
    masked_reference: str

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class BorrowerClarification(BaseModel):
    message: str
    options: list[BorrowerClarificationOption] = Field(min_length=2, max_length=20)


class AdminAssistantResponse(BaseModel):
    intent: AssistantIntent
    matched_route: str = "admin_assistant.unknown"
    intent_confidence: int = Field(default=0, ge=0, le=100)
    answer: str
    metrics: dict[str, str | int]
    records: list[AdminAssistantRecord] = Field(default_factory=list, max_length=50)
    clarification: BorrowerClarification | None = None
    as_of: date
    generated_at: datetime
    answer_source: Literal["local", "ai_enhanced", "offline"] = "local"
    ai_used: bool = False
    ai_status: AIStatus = "skipped"
    is_offline_capable: bool = True
    total_matching_count: int = 0
    returned_record_count: int = 0
    has_more: bool = False
    next_offset: int | None = None
    currency: str = "PHP"
    source: str = "Verified database records"
    disclaimer: str = (
        "Read-only assistant. Verify operational actions in the official record."
    )

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)
