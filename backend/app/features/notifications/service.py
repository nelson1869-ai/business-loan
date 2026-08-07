"""Centralized notification service for creating idempotent borrower notifications."""

import json
from datetime import UTC, datetime
from typing import Any
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.features.borrower_portal.models import BorrowerNotification

# Safe allowlisted metadata keys
ALLOWED_METADATA_KEYS = {
    "entityType",
    "entityId",
    "receiptId",
    "paymentId",
    "loanId",
    "requestId",
    "receipt_id",
    "payment_id",
    "loan_id",
    "request_id",
}


async def create_borrower_notification(
    db: AsyncSession,
    *,
    borrower_id: str,
    notification_type: str,
    title: str,
    message: str,
    entity_type: str | None = None,
    entity_id: str | None = None,
    metadata: dict[str, Any] | None = None,
    deduplication_key: str | None = None,
) -> BorrowerNotification:
    """Centralized, idempotent creation of borrower notifications.
    
    Prevents duplicate notifications on retries or duplicate events via deduplication_key.
    Enforces allowlisted minimal non-PII metadata.
    """
    if deduplication_key:
        stmt = select(BorrowerNotification).where(
            BorrowerNotification.deduplication_key == deduplication_key
        )
        res = await db.execute(stmt)
        existing = res.scalar_one_or_none()
        if existing is not None:
            return existing

    meta_payload: dict[str, Any] = {}
    if entity_type:
        meta_payload["entityType"] = entity_type
    if entity_id:
        meta_payload["entityId"] = entity_id

    if metadata:
        for k, v in metadata.items():
            if k in ALLOWED_METADATA_KEYS and v is not None:
                # Store string representation of IDs or simple scalars
                meta_payload[k] = str(v) if not isinstance(v, (int, float, bool)) else v

    metadata_json = json.dumps(meta_payload) if meta_payload else None

    notification = BorrowerNotification(
        id=str(uuid4()),
        borrower_id=borrower_id,
        title=title,
        message=message,
        notification_type=notification_type,
        metadata_json=metadata_json,
        deduplication_key=deduplication_key,
        is_read=False,
        created_at=datetime.now(UTC),
    )
    db.add(notification)
    await db.flush()
    return notification
