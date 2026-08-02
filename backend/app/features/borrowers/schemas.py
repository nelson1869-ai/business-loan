"""Borrower request and response schemas."""

from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.phone_numbers import normalize_ph_phone_number
from app.core.schemas.common import to_camel

BorrowerStatus = Literal["Pending", "Active", "Synced", "Defaulted", "Deleted"]


class BorrowerBase(BaseModel):
    """Fields shared by borrower payloads."""

    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)
    national_id: str = Field(min_length=4, max_length=100)
    phone: str = Field(min_length=7, max_length=32)
    date_of_birth: date
    status: BorrowerStatus = "Pending"

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)

    @field_validator("phone")
    @classmethod
    def normalize_phone(cls, value: str) -> str:
        """Store and return borrower phone numbers in canonical form."""
        return normalize_ph_phone_number(value)


class BorrowerCreate(BorrowerBase):
    """Payload accepted when registering a borrower."""

    id: str
    created_at: datetime

    @field_validator("id")
    @classmethod
    def validate_uuid(cls, value: str) -> str:
        """Require a canonical UUID string while preserving Flutter's string type."""
        return str(UUID(value))


class BorrowerUpdate(BaseModel):
    """Partial payload accepted when updating a borrower."""

    first_name: str | None = Field(default=None, min_length=1, max_length=100)
    last_name: str | None = Field(default=None, min_length=1, max_length=100)
    national_id: str | None = Field(default=None, min_length=4, max_length=100)
    phone: str | None = Field(default=None, min_length=7, max_length=32)
    date_of_birth: date | None = None
    status: BorrowerStatus | None = None

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)

    @field_validator("phone")
    @classmethod
    def normalize_phone(cls, value: str | None) -> str | None:
        """Normalize a supplied phone update while preserving omission."""
        return normalize_ph_phone_number(value) if value is not None else None


class BorrowerResponse(BorrowerBase):
    """Camel-case borrower representation returned to Flutter."""

    id: str
    created_at: datetime

    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        from_attributes=True,
    )


class BorrowerIdentityCheck(BaseModel):
    """PII-minimal request for authenticated registration preflight."""

    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)
    national_id: str = Field(min_length=4, max_length=100)
    phone: str = Field(min_length=7, max_length=32)
    date_of_birth: date

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)

    @field_validator("phone")
    @classmethod
    def normalize_phone(cls, value: str) -> str:
        return normalize_ph_phone_number(value)


class BorrowerIdentityCheckResponse(BaseModel):
    """Safe identity decision without returning borrower PII."""

    outcome: Literal["available", "restore", "existing", "conflict"]
    message: str
    borrower_id: str | None = None

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)
