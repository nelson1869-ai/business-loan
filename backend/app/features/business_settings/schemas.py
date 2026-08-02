"""Business presentation configuration schemas."""

from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.schemas.common import to_camel


class BusinessSettingUpdate(BaseModel):
    business_name: str = Field(min_length=1, max_length=160)
    currency_code: str = Field(min_length=3, max_length=3, pattern=r"^[A-Za-z]{3}$")
    receipt_footer: str = Field(max_length=500)
    timezone: str | None = Field(default=None, min_length=1, max_length=64)

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)

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

    model_config = ConfigDict(
        alias_generator=to_camel, populate_by_name=True, from_attributes=True
    )
