"""API schemas for versioned loan policies."""

from datetime import date, datetime
from decimal import Decimal
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.schemas.common import to_camel


class LoanPolicyCreate(BaseModel):
    policy_name: str = Field(min_length=1, max_length=160)
    version_number: int = Field(ge=1)
    currency: str = Field(min_length=3, max_length=3)
    interest_method: str = Field(
        default="fixed_periodic_reducing_balance", max_length=64
    )
    rate_period: str = Field(default="monthly", max_length=32)
    minimum_rate: Decimal = Field(ge=0, max_digits=10, decimal_places=8)
    maximum_rate: Decimal = Field(ge=0, max_digits=10, decimal_places=8)
    rounding_policy: dict[str, Any]
    payment_allocation_order: list[str] = Field(min_length=1)
    grace_period_configuration: dict[str, Any]
    late_fee_configuration: dict[str, Any]
    early_settlement_configuration: dict[str, Any]
    excess_payment_treatment: dict[str, Any]
    restructuring_policy: dict[str, Any]
    write_off_policy: dict[str, Any]
    contract_template_version: str = Field(min_length=1, max_length=64)
    effective_date: date
    change_reason: str = Field(min_length=1, max_length=2000)

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)

    @field_validator("minimum_rate", "maximum_rate", mode="before")
    @classmethod
    def reject_float_rates(cls, value: Any) -> Any:
        if isinstance(value, float):
            raise ValueError("must be sent as an exact decimal string")
        return value

    @field_validator("currency")
    @classmethod
    def normalize_currency(cls, value: str) -> str:
        return value.upper()


class LoanPolicyResponse(LoanPolicyCreate):
    id: str
    status: Literal["draft", "active", "retired"]
    created_by_user_id: str
    approved_by_user_id: str | None = None
    approved_at: datetime | None = None
    created_at: datetime

    model_config = ConfigDict(
        alias_generator=to_camel, populate_by_name=True, from_attributes=True
    )


class PolicyDecision(BaseModel):
    reason: str = Field(min_length=1, max_length=2000)
