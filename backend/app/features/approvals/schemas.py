"""Maker-checker request and decision API schemas."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.core.schemas.common import to_camel

SensitiveAction = Literal[
    "loan.approve",
    "loan.disburse",
    "loan.restructure",
    "loan.write_off",
    "payment.reverse",
    "policy.approve",
    "reconciliation.approve",
    "accounting.post_adjustment",
    "interest_rate.modify",
]


class ApprovalRequestCreate(BaseModel):
    action: SensitiveAction
    entity_type: str = Field(min_length=1, max_length=64, pattern=r"^[a-z_]+$")
    entity_id: str = Field(min_length=1, max_length=64)
    reason: str = Field(min_length=3, max_length=500)

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class ApprovalDecisionCreate(BaseModel):
    decision: Literal["approved", "rejected"]
    reason: str = Field(min_length=3, max_length=500)


class ApprovalRequestResponse(BaseModel):
    id: str
    action: str
    entity_type: str
    entity_id: str
    maker_user_id: str
    checker_user_id: str | None
    status: str
    decision: str | None
    request_reason: str
    decision_reason: str | None
    created_at: datetime
    decided_at: datetime | None
    consumed_at: datetime | None

    model_config = ConfigDict(
        from_attributes=True, alias_generator=to_camel, populate_by_name=True
    )
