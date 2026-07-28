"""Offline synchronization request and response schemas."""

from datetime import datetime
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.schemas.common import to_camel


class SyncQueueItem(BaseModel):
    """One ordered mutation captured by Flutter while offline."""

    transaction_uuid: str
    endpoint: str = Field(
        pattern=(
            r"^/api/v1/(?:"
            r"borrowers(?:/[0-9a-fA-F-]{36}"
            r"(?:/(?:notes|documents)"
            r"|/loans/[0-9a-fA-F-]{36}/(?:notes|documents))?)?"
            r"|loans(?:/[0-9a-fA-F-]{36}/payments"
            r"(?:/[0-9a-fA-F-]{36}/reversal)?)?"
            r"|notes/[0-9a-fA-F-]{36}"
            r"|documents/[0-9a-fA-F-]{36}"
            r"|collection-tasks(?:/[0-9a-fA-F-]{36}"
            r"/(?:complete|promise-status)|/[0-9a-fA-F-]{36}/[0-9]+/complete)?"
            r"|notifications/(?:read-all|[0-9a-fA-F-]{36}/read))$"
        )
    )
    method: Literal["POST", "PUT", "PATCH", "DELETE"]
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

    @model_validator(mode="after")
    def validate_unique_transaction_uuids(self) -> "SyncBatchRequest":
        """Require exactly one submitted operation per transaction UUID."""
        transaction_uuids = [item.transaction_uuid for item in self.items]
        if len(transaction_uuids) != len(set(transaction_uuids)):
            raise ValueError("Duplicate transaction UUIDs are not allowed")
        return self


class SyncFailure(BaseModel):
    """A queue item that could not be replayed."""

    transaction_uuid: str
    code: str = "UNKNOWN_ERROR"
    detail: str
    retryable: bool = False

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class SyncBatchResponse(BaseModel):
    """Per-item synchronization outcome returned to Flutter."""

    synced_transaction_uuids: list[str]
    failures: list[SyncFailure]

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)
