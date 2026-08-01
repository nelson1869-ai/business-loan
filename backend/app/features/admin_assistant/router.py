"""Admin-only, read-only conversational business reporting."""

import json
import logging
from uuid import uuid4

from fastapi import APIRouter, HTTPException, status

from app.core.config import get_settings
from app.core.dependencies import CurrentUser, DbSession
from app.core.rate_limiter import (
    FallbackRateLimiter,
    build_rate_limiter,
    opaque_rate_limit_key,
)
from app.features.admin_assistant.models import AuditLog
from app.features.admin_assistant.schemas import (
    AdminAssistantRequest,
    AdminAssistantResponse,
)
from app.features.admin_assistant.service import (
    BorrowerNotFound,
    UnsupportedAssistantQuestion,
    answer_admin_question,
    route_question,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/admin-assistant", tags=["Admin Assistant"])
_rate_limiter: FallbackRateLimiter | None = None
_rate_limiter_url: str | None = None


def _get_rate_limiter(redis_url: str | None) -> FallbackRateLimiter:
    global _rate_limiter, _rate_limiter_url
    normalized = redis_url.strip() if redis_url else None
    if _rate_limiter is None or normalized != _rate_limiter_url:
        _rate_limiter = build_rate_limiter(normalized)
        _rate_limiter_url = normalized
    return _rate_limiter


async def _audit_assistant_result(
    db: DbSession,
    *,
    user_id: str,
    correlation_id: str,
    result_category: str,
    intent: str | None = None,
    matched_route: str | None = None,
    confidence: int | None = None,
    record_count: int = 0,
    ai_status: str = "skipped",
) -> None:
    """Persist redacted metadata without allowing audit failure to break chat."""
    metadata = {
        "correlationId": correlation_id,
        "resultCategory": result_category,
        "recordCount": record_count,
        "aiStatus": ai_status,
        **({} if intent is None else {"intent": intent}),
        **({} if matched_route is None else {"matchedRoute": matched_route}),
        **({} if confidence is None else {"intentConfidence": confidence}),
    }
    try:
        db.add(
            AuditLog(
                id=str(uuid4()),
                user_id=user_id,
                action="AI_ADMIN_QUERY",
                entity_name="admin_assistant",
                entity_id=user_id,
                new_state_json=json.dumps(metadata, sort_keys=True),
            )
        )
        await db.commit()
    except Exception as error:
        try:
            await db.rollback()
        except Exception:
            pass
        logger.warning(
            "assistant_audit_failure",
            extra={
                "result_category": result_category,
                "failure_type": type(error).__name__,
            },
        )


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
    correlation_id = str(uuid4())
    limiter = _get_rate_limiter(settings.assistant_rate_limit_redis_url)
    limiter_key = opaque_rate_limit_key(
        "assistant",
        current_user.id,
        secret=settings.jwt_secret_key,
    )
    if not await limiter.allow(
        limiter_key,
        settings.assistant_rate_limit_per_minute,
    ):
        await _audit_assistant_result(
            db,
            user_id=current_user.id,
            correlation_id=correlation_id,
            result_category="rate_limited",
        )
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Assistant request limit reached. Wait a moment and try again.",
        )

    try:
        response = await answer_admin_question(
            db,
            payload.message,
            settings,
            selected_borrower_id=payload.selected_borrower_id,
            offset=payload.offset,
        )
    except BorrowerNotFound as error:
        route = route_question(payload.message)
        await _audit_assistant_result(
            db,
            user_id=current_user.id,
            correlation_id=correlation_id,
            result_category="borrower_not_found",
            intent=route.intent,
            matched_route=route.route,
            confidence=route.confidence,
        )
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(error),
        ) from error
    except UnsupportedAssistantQuestion as error:
        await _audit_assistant_result(
            db,
            user_id=current_user.id,
            correlation_id=correlation_id,
            result_category="unsupported_question",
        )
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(error),
        ) from error

    result_category = (
        "ai_provider_fallback"
        if response.ai_status
        in {"unavailable", "rate_limited", "cooldown", "invalid_response"}
        else "success"
    )
    await _audit_assistant_result(
        db,
        user_id=current_user.id,
        correlation_id=correlation_id,
        result_category=result_category,
        intent=response.intent,
        matched_route=response.matched_route,
        confidence=response.intent_confidence,
        record_count=len(response.records),
        ai_status=response.ai_status,
    )
    return response
