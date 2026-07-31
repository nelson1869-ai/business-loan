"""Business presentation configuration schemas."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.core.schemas.common import to_camel


class BusinessSettingUpdate(BaseModel):
    business_name: str = Field(min_length=1, max_length=160)
    currency_code: str = Field(min_length=3, max_length=3, pattern=r"^[A-Za-z]{3}$")
    receipt_footer: str = Field(max_length=500)

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class BusinessSettingResponse(BusinessSettingUpdate):
    updated_at: datetime

    model_config = ConfigDict(
        alias_generator=to_camel, populate_by_name=True, from_attributes=True
    )
