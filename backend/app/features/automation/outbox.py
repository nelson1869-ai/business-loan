"""Reliable PostgreSQL-backed outbox dispatcher service for n8n webhooks with HMAC authentication, exponential backoff, jitter, and dead-letter queue support."""

import asyncio
import json
import logging
import random
import time
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.features.automation.hmac import generate_hmac_signature
from app.features.automation.models import AutomationEventOutbox
from app.features.automation.schemas import DomainEventEnvelope, EventActor, EventEntity

logger = logging.getLogger(__name__)


def _send_signed_http_post(
    url: str,
    data_bytes: bytes,
    headers: dict[str, str],
    timeout_seconds: float = 5.0,
) -> tuple[int, str]:
    """Execute HTTP POST request using Python standard library."""
    req = urllib.request.Request(url, data=data_bytes, headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=timeout_seconds) as response:
        return response.getcode(), response.read().decode("utf-8")


async def publish_outbox_event(
    db: AsyncSession,
    envelope: DomainEventEnvelope[Any],
) -> AutomationEventOutbox:
    """Write domain event to outbox table within caller's active database transaction."""
    now = datetime.now(timezone.utc)
    outbox_record = AutomationEventOutbox(
        event_id=envelope.eventId,
        event_type=envelope.eventType,
        event_version=envelope.eventVersion,
        payload=envelope.model_dump(mode="json"),
        status="pending",
        attempt_count=0,
        next_attempt_at=now,
        created_at=now,
        updated_at=now,
        correlation_id=envelope.correlationId,
        idempotency_key=envelope.idempotencyKey,
    )
    db.add(outbox_record)
    logger.info(
        "Queued automation outbox event '%s' (type: %s, idempotency_key: %s)",
        envelope.eventId,
        envelope.eventType,
        envelope.idempotencyKey,
    )
    return outbox_record


async def dispatch_single_event(
    event: AutomationEventOutbox,
    secret: str | None,
    webhook_url: str,
    timeout_seconds: float = 5.0,
) -> tuple[bool, int, str]:
    """Send single outbox event to n8n webhook with HMAC signature."""
    timestamp_str = str(int(time.time()))
    payload_json = json.dumps(event.payload, separators=(",", ":"))
    data_bytes = payload_json.encode("utf-8")

    headers = {
        "Content-Type": "application/json",
        "User-Agent": "LendingNelson-Backend/1.0",
        "X-Lending-Event-Id": event.event_id,
        "X-Lending-Event-Type": event.event_type,
        "X-Lending-Timestamp": timestamp_str,
        "X-Lending-Correlation-Id": event.correlation_id,
    }

    if secret:
        signature = generate_hmac_signature(secret, timestamp_str, data_bytes)
        headers["X-Lending-Signature"] = signature

    try:
        status_code, resp_text = await asyncio.to_thread(
            _send_signed_http_post, webhook_url, data_bytes, headers, timeout_seconds
        )
        if 200 <= status_code < 300:
            return True, status_code, resp_text
        return False, status_code, f"HTTP {status_code}: {resp_text[:200]}"
    except Exception as exc:
        return False, 500, str(exc)


async def process_outbox_batch(
    db: AsyncSession,
    limit: int = 20,
) -> int:
    """Process pending automation events using bounded exponential backoff with jitter."""
    settings = get_settings()
    if not settings.n8n_webhook_url:
        logger.debug("n8n webhook URL not configured. Skipping outbox batch.")
        return 0

    now = datetime.now(timezone.utc)
    stmt = (
        select(AutomationEventOutbox)
        .where(
            AutomationEventOutbox.status.in_(["pending", "failed"]),
            (AutomationEventOutbox.next_attempt_at.is_(None))
            | (AutomationEventOutbox.next_attempt_at <= now),
            AutomationEventOutbox.attempt_count < settings.n8n_max_attempts,
        )
        .order_by(AutomationEventOutbox.created_at.asc())
        .limit(limit)
        .with_for_update(skip_locked=True)
    )

    result = await db.execute(stmt)
    pending_events: Sequence[AutomationEventOutbox] = result.scalars().all()

    if not pending_events:
        return 0

    processed_count = 0
    for event in pending_events:
        event.status = "processing"
        event.last_attempt_at = datetime.now(timezone.utc)
        event.attempt_count += 1

        success, status_code, error_or_resp = await dispatch_single_event(
            event=event,
            secret=settings.n8n_webhook_secret,
            webhook_url=settings.n8n_webhook_url,
            timeout_seconds=settings.n8n_timeout_seconds,
        )

        if success:
            event.status = "delivered"
            event.delivered_at = datetime.now(timezone.utc)
            event.last_error = None
            logger.info(
                "Delivered outbox event '%s' (type: %s)",
                event.event_id,
                event.event_type,
            )
        else:
            event.last_error = error_or_resp
            if event.attempt_count >= settings.n8n_max_attempts:
                event.status = "dead_lettered"
                logger.error(
                    "Outbox event '%s' reached max attempts (%d) and was dead-lettered. Last error: %s",
                    event.event_id,
                    event.attempt_count,
                    error_or_resp,
                )
            else:
                event.status = "failed"
                # Exponential backoff with jitter
                base_delay = settings.n8n_retry_base_seconds * (
                    2 ** (event.attempt_count - 1)
                )
                jitter = random.uniform(0, base_delay * 0.1)
                total_delay = base_delay + jitter
                event.next_attempt_at = datetime.now(timezone.utc) + timedelta(
                    seconds=total_delay
                )
                logger.warning(
                    "Failed delivery for event '%s' (attempt %d/%d). Retrying in %.1fs. Error: %s",
                    event.event_id,
                    event.attempt_count,
                    settings.n8n_max_attempts,
                    total_delay,
                    error_or_resp,
                )
        event.updated_at = datetime.now(timezone.utc)
        processed_count += 1

    await db.commit()
    return processed_count


async def replay_outbox_event(
    db: AsyncSession,
    event_id: str,
) -> AutomationEventOutbox | None:
    """Safely replay a failed or dead-lettered outbox event preserving original event_id."""
    stmt = select(AutomationEventOutbox).where(
        AutomationEventOutbox.event_id == event_id
    )
    result = await db.execute(stmt)
    event = result.scalar_one_or_none()

    if not event:
        return None

    if event.status == "processing":
        raise ValueError(
            f"Event '{event_id}' is currently processing and cannot be replayed."
        )

    now = datetime.now(timezone.utc)
    event.status = "pending"
    event.attempt_count = 0
    event.next_attempt_at = now
    event.last_error = None
    event.updated_at = now
    await db.commit()

    logger.info("Re-queued outbox event '%s' for manual replay", event_id)
    return event


async def dispatch_n8n_event(
    event_name: str,
    payload: dict[str, Any],
    db: AsyncSession | None = None,
    actor_id: str = "system-actor",
    actor_role: str = "system",
    entity_type: str = "general",
    entity_id: str = "0",
) -> None:
    """Helper wrapper to create event envelope and publish to outbox or direct fallback."""
    idempotency_key = f"{event_name}:{entity_type}:{entity_id}:{payload.get('payment_id') or payload.get('loan_id') or payload.get('id') or payload.get('request_id') or uuid.uuid4()}"
    envelope = DomainEventEnvelope[dict[str, Any]](
        eventType=event_name,
        idempotencyKey=idempotency_key,
        actor=EventActor(id=actor_id, role=actor_role),
        entity=EventEntity(type=entity_type, id=entity_id),
        data=payload,
    )

    if db is not None:
        await publish_outbox_event(db, envelope)
    else:
        # Direct dispatch fallback when DB session is not supplied
        settings = get_settings()
        if not settings.n8n_webhook_url:
            return
        dummy_event = AutomationEventOutbox(
            event_id=envelope.eventId,
            event_type=envelope.eventType,
            payload=envelope.model_dump(mode="json"),
            correlation_id=envelope.correlationId,
            idempotency_key=envelope.idempotencyKey,
        )
        await dispatch_single_event(
            event=dummy_event,
            secret=settings.n8n_webhook_secret,
            webhook_url=settings.n8n_webhook_url,
            timeout_seconds=settings.n8n_timeout_seconds,
        )
