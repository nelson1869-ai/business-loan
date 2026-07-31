"""Notification response schemas."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.core.schemas.common import to_camel


class NotificationResponse(BaseModel):
    id: str
    category: str
    priority: str
    title: str
    body: str
    borrower_id: str | None
    loan_id: str | None
    created_at: datetime
    read_at: datetime | None

    model_config = ConfigDict(
        alias_generator=to_camel, populate_by_name=True, from_attributes=True
    )
