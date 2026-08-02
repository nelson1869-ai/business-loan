"""Write-off and recovery command schemas."""

from datetime import date, datetime
from decimal import Decimal
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.schemas.common import to_camel


class WriteOffCreate(BaseModel):
    approval_request_id: str
    amount: Decimal = Field(gt=0, max_digits=18, decimal_places=2)
    effective_date: date
    reason: str = Field(min_length=3, max_length=500)

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)

    @field_validator("approval_request_id")
    @classmethod
    def validate_approval(cls, value: str) -> str:
        return str(UUID(value))

    @field_validator("amount", mode="before")
    @classmethod
    def reject_float(cls, value: Any) -> Any:
        if isinstance(value, float):
            raise ValueError("must be sent as an exact decimal string")
        return value


class RecoveryCreate(BaseModel):
    request_id: str
    amount: Decimal = Field(gt=0, max_digits=18, decimal_places=2)
    effective_date: date
    note: str | None = Field(default=None, max_length=500)

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)

    @field_validator("request_id")
    @classmethod
    def validate_request(cls, value: str) -> str:
        return str(UUID(value))

    @field_validator("amount", mode="before")
    @classmethod
    def reject_float(cls, value: Any) -> Any:
        if isinstance(value, float):
            raise ValueError("must be sent as an exact decimal string")
        return value


class RecoveryResponse(BaseModel):
    id: str
    request_id: str
    write_off_id: str
    amount: Decimal
    effective_date: date
    note: str | None
    recorded_by_user_id: str
    created_at: datetime

    model_config = ConfigDict(
        from_attributes=True, alias_generator=to_camel, populate_by_name=True
    )


class WriteOffResponse(BaseModel):
    id: str
    loan_id: str
    approval_request_id: str
    amount: Decimal
    effective_date: date
    reason: str
    written_off_by_user_id: str
    created_at: datetime
    recoveries: list[RecoveryResponse]

    model_config = ConfigDict(
        from_attributes=True, alias_generator=to_camel, populate_by_name=True
    )
