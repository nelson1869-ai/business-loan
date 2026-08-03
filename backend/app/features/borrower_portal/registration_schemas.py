"""Strict public and staff schemas for borrower self-registration."""

from datetime import date, datetime
from typing import Literal

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)

from app.core.phone_numbers import normalize_ph_phone_number
from app.core.schemas.common import to_camel


class StrictSchema(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        extra="forbid",
        from_attributes=True,
    )


class RegistrationCreate(StrictSchema):
    first_name: str = Field(min_length=1, max_length=100)
    middle_name: str | None = Field(default=None, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)
    suffix: str | None = Field(default=None, max_length=30)
    national_id: str = Field(min_length=4, max_length=100)
    phone_number: str = Field(min_length=7, max_length=32)
    date_of_birth: date
    email: str | None = Field(
        default=None, max_length=254, pattern=r"^[^\s@]+@[^\s@]+\.[^\s@]+$"
    )
    privacy_accepted: bool
    terms_accepted: bool

    @field_validator("phone_number")
    @classmethod
    def normalize_phone(cls, value: str) -> str:
        return normalize_ph_phone_number(value)

    @field_validator("national_id")
    @classmethod
    def normalize_national_id(cls, value: str) -> str:
        normalized = value.strip()
        if len(normalized) < 4:
            raise ValueError("National ID must be at least 4 characters")
        return normalized

    @model_validator(mode="after")
    def validate_consent_and_birth_date(self) -> "RegistrationCreate":
        if not self.privacy_accepted or not self.terms_accepted:
            raise ValueError("Privacy notice and terms must be accepted")
        today = date.today()
        if self.date_of_birth >= today:
            raise ValueError("Date of birth must be in the past")
        if self.date_of_birth.year < today.year - 120:
            raise ValueError("Date of birth is invalid")
        return self


class RegistrationSubmitted(StrictSchema):
    request_id: str
    registration_token: str
    status: Literal["pending"] = "pending"
    message: str = "Your registration was submitted for review."


class RegistrationStatusRequest(StrictSchema):
    registration_token: str = Field(min_length=32, max_length=256)


class RegistrationStatusResponse(StrictSchema):
    status: Literal[
        "pending", "approved", "rejected", "cancelled", "expired", "active", "unknown"
    ]
    message: str


class RegistrationListItem(StrictSchema):
    id: str
    first_name: str
    middle_name: str | None
    last_name: str
    suffix: str | None
    masked_national_id: str
    has_national_id: bool
    masked_phone: str
    date_of_birth: date
    email: str | None
    status: str
    submitted_at: datetime
    linked_borrower_id: str | None


class RegistrationApproval(StrictSchema):
    borrower_id: str
    review_notes: str | None = Field(default=None, max_length=1000)


class RegistrationCreateAndApproval(StrictSchema):
    national_id: str | None = Field(default=None, min_length=4, max_length=100)
    review_notes: str | None = Field(default=None, max_length=1000)

    @field_validator("national_id")
    @classmethod
    def normalize_national_id(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        if len(normalized) < 4:
            raise ValueError("National ID must be at least 4 characters")
        return normalized


class RegistrationRejection(StrictSchema):
    reason: str = Field(min_length=1, max_length=500)


class AccountAction(StrictSchema):
    reason: str = Field(min_length=1, max_length=500)


class AccountRelink(AccountAction):
    borrower_id: str


class AccountActionResponse(StrictSchema):
    account_id: str
    account_status: str
    borrower_id: str
