"""Authenticated per-user notification inbox."""

from datetime import UTC, datetime
from fastapi import APIRouter, HTTPException, Response, status
from sqlalchemy import select, update

from app.dependencies import CurrentUser, DbSession
from app.models.notification import Notification
from app.schemas.notification import NotificationResponse

router = APIRouter(prefix="/api/v1/notifications", tags=["Notifications"])


@router.get("", response_model=list[NotificationResponse])
async def list_notifications(db: DbSession, current_user: CurrentUser) -> list[Notification]:
    return list(
        (
            await db.execute(
                select(Notification)
                .where(Notification.user_id == current_user.id)
                .order_by(Notification.created_at.desc())
                .limit(100)
            )
        ).scalars()
    )


@router.post("/{notification_id}/read", status_code=status.HTTP_204_NO_CONTENT)
async def mark_read(notification_id: str, db: DbSession, current_user: CurrentUser) -> Response:
    notification = await db.get(Notification, notification_id)
    if notification is None or notification.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Notification not found")
    notification.read_at = notification.read_at or datetime.now(UTC)
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/read-all", status_code=status.HTTP_204_NO_CONTENT)
async def mark_all_read(db: DbSession, current_user: CurrentUser) -> Response:
    await db.execute(
        update(Notification)
        .where(Notification.user_id == current_user.id, Notification.read_at.is_(None))
        .values(read_at=datetime.now(UTC))
    )
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
