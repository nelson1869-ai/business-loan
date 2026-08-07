"""Business presentation configuration schemas."""

from datetime import datetime
from decimal import Decimal
from typing import Any
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.schemas.common import to_camel


class BusinessSettingUpdate(BaseModel):
    business_name: str = Field(min_length=1, max_length=160)
    currency_code: str = Field(min_length=3, max_length=3, pattern=r"^[A-Za-z]{3}$")
    receipt_footer: str = Field(max_length=500)
    timezone: str | None = Field(default=None, min_length=1, max_length=64)
    default_monthly_estimate_rate: Decimal | None = Field(
        default=None,
        alias="defaultMonthlyEstimateRate",
        ge=0,
        max_digits=10,
        decimal_places=8,
    )

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)

    @field_validator("default_monthly_estimate_rate", mode="before")
    @classmethod
    def reject_float_rate(cls, value: Any) -> Any:
        """Require exact decimal string or None instead of binary float."""
        if isinstance(value, float):
            raise ValueError("must be sent as an exact decimal string")
        return value

    @field_validator("timezone")
    @classmethod
    def validate_timezone(cls, value: str | None) -> str | None:
        if value is None:
            return None
        try:
            ZoneInfo(value)
        except ZoneInfoNotFoundError as error:
            raise ValueError("must be a valid IANA timezone") from error
        return value


class BusinessSettingResponse(BusinessSettingUpdate):
    timezone: str
    updated_at: datetime
    default_monthly_estimate_rate: Decimal | None = Field(
        default=None, alias="defaultMonthlyEstimateRate"
    )

    model_config = ConfigDict(
        alias_generator=to_camel, populate_by_name=True, from_attributes=True
    )
