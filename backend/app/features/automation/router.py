"""Operational endpoints for automation event outbox management and health monitoring."""

from datetime import datetime, timezone
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import func, select

from app.core.config import get_settings
from app.core.dependencies import DbSession
from app.core.service_auth import verify_service_account_or_admin
from app.features.automation.models import AutomationEventOutbox
from app.features.automation.outbox import process_outbox_batch, replay_outbox_event

router = APIRouter(prefix="/api/v1/automation", tags=["automation"])

ServiceOrAdminUser = Annotated[Any, Depends(verify_service_account_or_admin)]


class OutboxEventSummaryResponse(BaseModel):
    id: str
    event_id: str
    event_type: str
    event_version: int
    status: str
    attempt_count: int
    next_attempt_at: str | None
    last_attempt_at: str | None
    delivered_at: str | None
    last_error: str | None
    created_at: str
    updated_at: str
    correlation_id: str
    idempotency_key: str
    payload: dict[str, Any]


class OutboxPaginatedResponse(BaseModel):
    items: list[OutboxEventSummaryResponse]
    total: int
    page: int
    page_size: int


class AutomationHealthResponse(BaseModel):
    n8n_enabled: bool
    n8n_webhook_configured: bool
    pending_count: int
    processing_count: int
    delivered_count: int
    failed_count: int
    dead_lettered_count: int
    total_count: int


@router.get("/health", response_model=AutomationHealthResponse)
async def get_automation_health(
    db: DbSession,
    actor: ServiceOrAdminUser,
) -> AutomationHealthResponse:
    """Check automation event outbox health and queue metrics."""
    settings = get_settings()

    async def _count_status(status_val: str) -> int:
        stmt = select(func.count(AutomationEventOutbox.id)).where(
            AutomationEventOutbox.status == status_val
        )
        res = await db.execute(stmt)
        return res.scalar_one() or 0

    pending = await _count_status("pending")
    processing = await _count_status("processing")
    delivered = await _count_status("delivered")
    failed = await _count_status("failed")
    dead_lettered = await _count_status("dead_lettered")

    total_stmt = select(func.count(AutomationEventOutbox.id))
    total_res = await db.execute(total_stmt)
    total = total_res.scalar_one() or 0

    return AutomationHealthResponse(
        n8n_enabled=settings.n8n_enabled,
        n8n_webhook_configured=bool(settings.n8n_webhook_url),
        pending_count=pending,
        processing_count=processing,
        delivered_count=delivered,
        failed_count=failed,
        dead_lettered_count=dead_lettered,
        total_count=total,
    )


@router.get("/events", response_model=OutboxPaginatedResponse)
async def list_outbox_events(
    db: DbSession,
    actor: ServiceOrAdminUser,
    status_filter: str | None = Query(None, alias="status"),
    event_type_filter: str | None = Query(None, alias="event_type"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
) -> OutboxPaginatedResponse:
    """List outbox events with optional status/type filtering and pagination."""
    query = select(AutomationEventOutbox)
    count_query = select(func.count(AutomationEventOutbox.id))

    if status_filter:
        query = query.where(
            AutomationEventOutbox.status == status_filter.lower().strip()
        )
        count_query = count_query.where(
            AutomationEventOutbox.status == status_filter.lower().strip()
        )

    if event_type_filter:
        query = query.where(
            AutomationEventOutbox.event_type == event_type_filter.strip()
        )
        count_query = count_query.where(
            AutomationEventOutbox.event_type == event_type_filter.strip()
        )

    total_res = await db.execute(count_query)
    total = total_res.scalar_one() or 0

    offset = (page - 1) * page_size
    query = (
        query.order_by(AutomationEventOutbox.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )

    res = await db.execute(query)
    events = res.scalars().all()

    items = [
        OutboxEventSummaryResponse(
            id=ev.id,
            event_id=ev.event_id,
            event_type=ev.event_type,
            event_version=ev.event_version or 1,
            status=ev.status,
            attempt_count=ev.attempt_count,
            next_attempt_at=ev.next_attempt_at.isoformat()
            if ev.next_attempt_at
            else None,
            last_attempt_at=ev.last_attempt_at.isoformat()
            if ev.last_attempt_at
            else None,
            delivered_at=ev.delivered_at.isoformat() if ev.delivered_at else None,
            last_error=ev.last_error,
            created_at=ev.created_at.isoformat()
            if ev.created_at
            else datetime.now(timezone.utc).isoformat(),
            updated_at=ev.updated_at.isoformat()
            if ev.updated_at
            else datetime.now(timezone.utc).isoformat(),
            correlation_id=ev.correlation_id,
            idempotency_key=ev.idempotency_key,
            payload=ev.payload,
        )
        for ev in events
    ]

    return OutboxPaginatedResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/events/{event_id}", response_model=OutboxEventSummaryResponse)
async def get_outbox_event(
    event_id: str,
    db: DbSession,
    actor: ServiceOrAdminUser,
) -> OutboxEventSummaryResponse:
    """Retrieve details for a single outbox event."""
    stmt = select(AutomationEventOutbox).where(
        (AutomationEventOutbox.event_id == event_id)
        | (AutomationEventOutbox.id == event_id)
    )
    res = await db.execute(stmt)
    ev = res.scalar_one_or_none()

    if not ev:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Outbox event '{event_id}' not found.",
        )

    return OutboxEventSummaryResponse(
        id=ev.id,
        event_id=ev.event_id,
        event_type=ev.event_type,
        event_version=ev.event_version,
        status=ev.status,
        attempt_count=ev.attempt_count,
        next_attempt_at=ev.next_attempt_at.isoformat() if ev.next_attempt_at else None,
        last_attempt_at=ev.last_attempt_at.isoformat() if ev.last_attempt_at else None,
        delivered_at=ev.delivered_at.isoformat() if ev.delivered_at else None,
        last_error=ev.last_error,
        created_at=ev.created_at.isoformat()
        if ev.created_at
        else datetime.now(timezone.utc).isoformat(),
        updated_at=ev.updated_at.isoformat()
        if ev.updated_at
        else datetime.now(timezone.utc).isoformat(),
        correlation_id=ev.correlation_id,
        idempotency_key=ev.idempotency_key,
        payload=ev.payload,
    )


@router.post("/events/{event_id}/retry", response_model=OutboxEventSummaryResponse)
async def retry_outbox_event(
    event_id: str,
    db: DbSession,
    actor: ServiceOrAdminUser,
) -> OutboxEventSummaryResponse:
    """Manually re-queue a failed or dead-lettered outbox event."""
    try:
        ev = await replay_outbox_event(db, event_id)
    except ValueError as err:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(err),
        ) from err

    if not ev:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Outbox event '{event_id}' not found.",
        )

    await process_outbox_batch(db, limit=10)

    res = await db.execute(
        select(AutomationEventOutbox).where(AutomationEventOutbox.id == ev.id)
    )
    updated_ev = res.scalar_one()

    return OutboxEventSummaryResponse(
        id=updated_ev.id,
        event_id=updated_ev.event_id,
        event_type=updated_ev.event_type,
        event_version=updated_ev.event_version,
        status=updated_ev.status,
        attempt_count=updated_ev.attempt_count,
        next_attempt_at=updated_ev.next_attempt_at.isoformat()
        if updated_ev.next_attempt_at
        else None,
        last_attempt_at=updated_ev.last_attempt_at.isoformat()
        if updated_ev.last_attempt_at
        else None,
        delivered_at=updated_ev.delivered_at.isoformat()
        if updated_ev.delivered_at
        else None,
        last_error=updated_ev.last_error,
        created_at=updated_ev.created_at.isoformat(),
        updated_at=updated_ev.updated_at.isoformat(),
        correlation_id=updated_ev.correlation_id,
        idempotency_key=updated_ev.idempotency_key,
        payload=updated_ev.payload,
    )
