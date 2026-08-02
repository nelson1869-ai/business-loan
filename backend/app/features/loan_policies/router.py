"""Administrative API for versioned loan policies."""

from fastapi import APIRouter, HTTPException
from sqlalchemy import select

from app.core.authorization import require_any_permission, require_permission
from app.core.dependencies import CurrentUser, DbSession
from app.features.loan_policies import service
from app.features.loan_policies.models import LoanPolicyVersion
from app.features.loan_policies.schemas import (
    LoanPolicyCreate,
    LoanPolicyResponse,
    PolicyDecision,
)

router = APIRouter(prefix="/api/v1/loan-policies", tags=["Loan Policies"])


def _require_admin(user: CurrentUser) -> None:
    require_any_permission(user, ("policy.create", "policy.approve"))


@router.post("", response_model=LoanPolicyResponse, status_code=201)
async def create(payload: LoanPolicyCreate, db: DbSession, current_user: CurrentUser):
    require_permission(current_user, "policy.create")
    try:
        policy = await service.create_policy(db, payload, current_user)
        await db.commit()
        await db.refresh(policy)
        return policy
    except ValueError as error:
        await db.rollback()
        raise HTTPException(status_code=422, detail=str(error)) from error


@router.get("", response_model=list[LoanPolicyResponse])
async def list_policies(db: DbSession, current_user: CurrentUser):
    _require_admin(current_user)
    result = await db.execute(
        select(LoanPolicyVersion).order_by(
            LoanPolicyVersion.policy_name, LoanPolicyVersion.version_number.desc()
        )
    )
    return list(result.scalars())


@router.post("/{policy_id}/activate", response_model=LoanPolicyResponse)
async def activate(
    policy_id: str, payload: PolicyDecision, db: DbSession, current_user: CurrentUser
):
    require_permission(current_user, "policy.approve")
    try:
        policy = await service.activate_policy(
            db, policy_id, current_user, payload.reason
        )
        await db.commit()
        await db.refresh(policy)
        return policy
    except PermissionError as error:
        await db.rollback()
        raise HTTPException(status_code=403, detail=str(error)) from error
    except ValueError as error:
        await db.rollback()
        raise HTTPException(status_code=409, detail=str(error)) from error


@router.post("/{policy_id}/retire", response_model=LoanPolicyResponse)
async def retire(
    policy_id: str, payload: PolicyDecision, db: DbSession, current_user: CurrentUser
):
    require_permission(current_user, "policy.approve")
    try:
        policy = await service.retire_policy(
            db, policy_id, current_user, payload.reason
        )
        await db.commit()
        await db.refresh(policy)
        return policy
    except ValueError as error:
        await db.rollback()
        raise HTTPException(status_code=409, detail=str(error)) from error
