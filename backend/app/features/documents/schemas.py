"""Document API request and response schemas."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.core.schemas.common import to_camel


class DocumentCreate(BaseModel):
    title: str = Field(min_length=1, max_length=160)
    file_name: str = Field(min_length=1, max_length=255)
    content_type: str = Field(min_length=1, max_length=100)
    content_base64: str = Field(min_length=1, max_length=950_000)

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class DocumentResponse(BaseModel):
    id: str
    borrower_id: str
    loan_id: str | None
    uploaded_by_user_id: str
    title: str
    file_name: str
    content_type: str
    size_bytes: int
    created_at: datetime
    can_delete: bool

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)
