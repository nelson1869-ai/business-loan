"""Admin-only, read-only conversational business reporting."""

import json
from collections import defaultdict, deque
from time import monotonic
from uuid import uuid4

from fastapi import APIRouter, HTTPException, status

from app.config import get_settings
from app.dependencies import CurrentUser, DbSession
from app.models.audit_log import AuditLog
from app.schemas.admin_assistant import AdminAssistantRequest, AdminAssistantResponse
from app.services.admin_assistant_service import (
    BorrowerNotFound,
    UnsupportedAssistantQuestion,
    answer_admin_question,
)

router = APIRouter(prefix="/api/v1/admin-assistant", tags=["Admin Assistant"])
_assistant_requests: dict[str, deque[float]] = defaultdict(deque)


def _enforce_rate_limit(user_id: str, limit: int) -> None:
    """Apply a bounded per-admin process-local request limit."""
    now = monotonic()
    requests = _assistant_requests[user_id]
    while requests and now - requests[0] >= 60:
        requests.popleft()
    if len(requests) >= limit:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Assistant request limit reached. Wait a moment and try again.",
        )
    requests.append(now)


@router.post("/chat", response_model=AdminAssistantResponse)
@router.post("/questions", response_model=AdminAssistantResponse)
async def admin_assistant_chat(
    payload: AdminAssistantRequest,
    db: DbSession,
    current_user: CurrentUser,
) -> AdminAssistantResponse:
    """Answer one allowlisted business question using verified database records."""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Administrator access required",
        )
    settings = get_settings()
    _enforce_rate_limit(current_user.id, settings.assistant_rate_limit_per_minute)
    try:
        response = await answer_admin_question(
            db,
            payload.message,
            settings,
            selected_borrower_id=payload.selected_borrower_id,
            offset=payload.offset,
        )
    except BorrowerNotFound as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(error),
        ) from error
    except UnsupportedAssistantQuestion as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(error),
        ) from error

    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=current_user.id,
            action="AI_ADMIN_QUERY",
            entity_name="admin_assistant",
            entity_id=current_user.id,
            new_state_json=json.dumps(
                {
                    "intent": response.intent,
                    "matchedRoute": response.matched_route,
                    "intentConfidence": response.intent_confidence,
                    "recordCount": len(response.records),
                    "asOf": response.as_of.isoformat(),
                }
            ),
        )
    )
    await db.commit()
    return response
