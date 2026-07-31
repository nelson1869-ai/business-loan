"""Authenticated per-user notification inbox."""

from datetime import UTC, datetime
from uuid import uuid4

from fastapi import APIRouter, HTTPException, Query, Response, status
from sqlalchemy import select, update

from app.core.dependencies import CurrentUser, DbSession
from app.features.admin_assistant.models import AuditLog
from app.features.notifications.models import Notification
from app.features.notifications.schemas import NotificationResponse

router = APIRouter(prefix="/api/v1/notifications", tags=["Notifications"])


@router.get("", response_model=list[NotificationResponse])
async def list_notifications(
    db: DbSession,
    current_user: CurrentUser,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=50, ge=1, le=100),
) -> list[Notification]:
    return list(
        (
            await db.execute(
                select(Notification)
                .where(Notification.user_id == current_user.id)
                .order_by(Notification.created_at.desc())
                .offset(offset)
                .limit(limit)
            )
        ).scalars()
    )


@router.post("/{notification_id}/read", status_code=status.HTTP_204_NO_CONTENT)
async def mark_read(
    notification_id: str, db: DbSession, current_user: CurrentUser
) -> Response:
    notification = await db.get(Notification, notification_id)
    if notification is None or notification.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Notification not found")
    notification.read_at = notification.read_at or datetime.now(UTC)
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=current_user.id,
            action="read_notification",
            entity_name="notification",
            entity_id=notification.id,
            new_state_json='{"read":true}',
        )
    )
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/read-all", status_code=status.HTTP_204_NO_CONTENT)
async def mark_all_read(db: DbSession, current_user: CurrentUser) -> Response:
    await db.execute(
        update(Notification)
        .where(Notification.user_id == current_user.id, Notification.read_at.is_(None))
        .values(read_at=datetime.now(UTC))
    )
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=current_user.id,
            action="read_all_notifications",
            entity_name="notification",
            entity_id=current_user.id,
            new_state_json='{"read":true}',
        )
    )
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
