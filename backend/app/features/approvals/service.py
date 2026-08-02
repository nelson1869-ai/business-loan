"""Race-safe maker-checker request lifecycle."""

import json
from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.features.admin_assistant.models import AuditLog
from app.features.approvals.models import ApprovalRequest
from app.features.users.models import User


async def create_request(
    db: AsyncSession,
    *,
    action: str,
    entity_type: str,
    entity_id: str,
    maker: User,
    reason: str,
    before_state: dict[str, str] | None = None,
    after_state: dict[str, str] | None = None,
) -> ApprovalRequest:
    request = ApprovalRequest(
        id=str(uuid4()),
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        maker_user_id=maker.id,
        status="pending",
        request_reason=reason.strip(),
        before_state_json=json.dumps(before_state) if before_state else None,
        after_state_json=json.dumps(after_state) if after_state else None,
    )
    db.add(request)
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=maker.id,
            action="CREATE_APPROVAL_REQUEST",
            entity_name="approval_request",
            entity_id=request.id,
            new_state_json=json.dumps(
                {"action": action, "entityType": entity_type, "entityId": entity_id}
            ),
        )
    )
    await db.flush()
    return request


async def decide_request(
    db: AsyncSession,
    request_id: str,
    checker: User,
    decision: str,
    reason: str,
) -> ApprovalRequest:
    request = await db.scalar(
        select(ApprovalRequest)
        .where(ApprovalRequest.id == request_id)
        .with_for_update()
    )
    if request is None:
        raise ValueError("Approval request not found")
    if request.status != "pending":
        raise ValueError("Approval request already has a final decision")
    if request.maker_user_id == checker.id:
        raise PermissionError("Maker cannot approve or reject own request")
    if decision not in {"approved", "rejected"}:
        raise ValueError("Invalid approval decision")
    request.checker_user_id = checker.id
    request.decision = decision
    request.status = decision
    request.decision_reason = reason.strip()
    request.decided_at = datetime.now(UTC)
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=checker.id,
            action=f"{decision.upper()}_APPROVAL_REQUEST",
            entity_name="approval_request",
            entity_id=request.id,
            old_state_json='{"status":"pending"}',
            new_state_json=json.dumps(
                {"status": decision, "action": request.action, "reason": reason.strip()}
            ),
        )
    )
    await db.flush()
    return request


async def consume_approved_request(
    db: AsyncSession,
    *,
    request_id: str,
    action: str,
    entity_type: str,
    entity_id: str,
    maker: User,
) -> ApprovalRequest:
    request = await db.scalar(
        select(ApprovalRequest)
        .where(ApprovalRequest.id == request_id)
        .with_for_update()
    )
    if request is None:
        raise ValueError("Approval request not found")
    if request.status != "approved":
        raise ValueError("An approved, unconsumed request is required")
    if (
        request.action != action
        or request.entity_type != entity_type
        or request.entity_id != entity_id
    ):
        raise ValueError("Approval request does not match this action and entity")
    if request.maker_user_id != maker.id:
        raise PermissionError("Only the approval maker may execute the approved action")
    request.status = "consumed"
    request.consumed_at = datetime.now(UTC)
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=maker.id,
            action="CONSUME_APPROVAL_REQUEST",
            entity_name="approval_request",
            entity_id=request.id,
            old_state_json='{"status":"approved"}',
            new_state_json='{"status":"consumed"}',
        )
    )
    await db.flush()
    return request
