"""Granular maker-checker approval endpoints."""

from fastapi import APIRouter, HTTPException
from sqlalchemy import or_, select
from sqlalchemy.exc import IntegrityError

from app.core.authorization import has_permission, require_permission
from app.core.dependencies import CurrentUser, DbSession
from app.features.approvals import service
from app.features.approvals.models import ApprovalRequest
from app.features.approvals.schemas import (
    ApprovalDecisionCreate,
    ApprovalRequestCreate,
    ApprovalRequestResponse,
)

router = APIRouter(prefix="/api/v1/approvals", tags=["Approvals"])

ACTION_PERMISSION = {
    "loan.approve": "loan.approve",
    "loan.disburse": "loan.disburse",
    "loan.restructure": "loan.restructure",
    "loan.write_off": "loan.write_off",
    "payment.reverse": "payment.reverse",
    "policy.approve": "policy.approve",
    "reconciliation.approve": "reconciliation.approve",
    "accounting.post_adjustment": "accounting.post_adjustment",
    "interest_rate.modify": "loan.approve",
}

REQUEST_PERMISSION = {
    **ACTION_PERMISSION,
    "loan.approve": "loan.create",
    "payment.reverse": "payment.collect",
    "loan.write_off": "loan.write_off",
}


@router.post("", response_model=ApprovalRequestResponse, status_code=201)
async def create_approval_request(
    payload: ApprovalRequestCreate,
    db: DbSession,
    current_user: CurrentUser,
) -> ApprovalRequest:
    require_permission(current_user, REQUEST_PERMISSION[payload.action])
    try:
        request = await service.create_request(
            db,
            action=payload.action,
            entity_type=payload.entity_type,
            entity_id=payload.entity_id,
            maker=current_user,
            reason=payload.reason,
        )
        await db.commit()
        await db.refresh(request)
        return request
    except IntegrityError as error:
        await db.rollback()
        raise HTTPException(
            status_code=409,
            detail="A pending approval already exists for this action and entity",
        ) from error


@router.get("", response_model=list[ApprovalRequestResponse])
async def list_approval_requests(
    db: DbSession, current_user: CurrentUser
) -> list[ApprovalRequest]:
    query = select(ApprovalRequest).order_by(ApprovalRequest.created_at.desc())
    if not has_permission(current_user, "audit.view"):
        query = query.where(
            or_(
                ApprovalRequest.maker_user_id == current_user.id,
                ApprovalRequest.checker_user_id == current_user.id,
            )
        )
    return list((await db.execute(query)).scalars())


@router.post("/{request_id}/decision", response_model=ApprovalRequestResponse)
async def decide_approval_request(
    request_id: str,
    payload: ApprovalDecisionCreate,
    db: DbSession,
    current_user: CurrentUser,
) -> ApprovalRequest:
    pending = await db.get(ApprovalRequest, request_id)
    if pending is None:
        raise HTTPException(status_code=404, detail="Approval request not found")
    require_permission(current_user, ACTION_PERMISSION[pending.action])
    try:
        request = await service.decide_request(
            db, request_id, current_user, payload.decision, payload.reason
        )
        await db.commit()
        await db.refresh(request)
        return request
    except PermissionError as error:
        await db.rollback()
        raise HTTPException(status_code=403, detail=str(error)) from error
    except ValueError as error:
        await db.rollback()
        raise HTTPException(status_code=409, detail=str(error)) from error
