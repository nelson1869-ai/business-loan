"""Read-only accounting API schemas."""

from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict

from app.core.schemas.common import to_camel


class AccountResponse(BaseModel):
    id: str
    code: str
    name: str
    category: str
    currency: str
    is_active: bool

    model_config = ConfigDict(
        from_attributes=True, alias_generator=to_camel, populate_by_name=True
    )


class JournalLineResponse(BaseModel):
    line_number: int
    account_id: str
    debit: Decimal
    credit: Decimal
    memo: str

    model_config = ConfigDict(
        from_attributes=True, alias_generator=to_camel, populate_by_name=True
    )


class JournalEntryResponse(BaseModel):
    id: str
    period_id: str
    currency: str
    posted_at: datetime
    actor_user_id: str
    source_type: str
    source_record_id: str
    idempotency_key: str
    request_id: str | None
    description: str
    status: str
    reconciliation_status: str
    lines: list[JournalLineResponse]

    model_config = ConfigDict(
        from_attributes=True, alias_generator=to_camel, populate_by_name=True
    )


class TrialBalanceRow(BaseModel):
    account_code: str
    account_name: str
    debit: Decimal
    credit: Decimal

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class TrialBalanceResponse(BaseModel):
    as_of: datetime
    currency: str
    total_debit: Decimal
    total_credit: Decimal
    rows: list[TrialBalanceRow]

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)
