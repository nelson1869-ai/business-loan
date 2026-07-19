"""Offline synchronization request and response schemas."""

from datetime import datetime
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.common import to_camel


class SyncQueueItem(BaseModel):
    """One ordered mutation captured by Flutter while offline."""

    transaction_uuid: str
    endpoint: str = Field(pattern=r"^/api/v1/borrowers(?:/[0-9a-fA-F-]{36})?$")
    method: Literal["POST", "PUT", "DELETE"]
    payload: dict[str, Any] = Field(default_factory=dict)
    created_at: datetime

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)

    @field_validator("transaction_uuid")
    @classmethod
    def validate_transaction_uuid(cls, value: str) -> str:
        """Validate and normalize the client transaction UUID."""
        return str(UUID(value))


class SyncBatchRequest(BaseModel):
    """An ordered batch of offline mutations."""

    items: list[SyncQueueItem] = Field(max_length=100)


class SyncFailure(BaseModel):
    """A queue item that could not be replayed."""

    transaction_uuid: str
    detail: str

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class SyncBatchResponse(BaseModel):
    """Per-item synchronization outcome returned to Flutter."""

    synced_transaction_uuids: list[str]
    failures: list[SyncFailure]

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)
