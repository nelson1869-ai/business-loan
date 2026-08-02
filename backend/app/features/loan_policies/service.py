"""Approval and snapshot services for immutable loan policy versions."""

import json
from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.features.admin_assistant.models import AuditLog
from app.features.loan_policies.models import LoanPolicyVersion
from app.features.loan_policies.schemas import LoanPolicyCreate
from app.features.users.models import User


def policy_snapshot(policy: LoanPolicyVersion) -> dict:
    """Return the immutable financial policy material copied onto a loan."""
    return {
        "policyVersionId": policy.id,
        "policyName": policy.policy_name,
        "versionNumber": policy.version_number,
        "currency": policy.currency,
        "interestMethod": policy.interest_method,
        "ratePeriod": policy.rate_period,
        "minimumRate": str(policy.minimum_rate),
        "maximumRate": str(policy.maximum_rate),
        "roundingPolicy": policy.rounding_policy,
        "paymentAllocationOrder": policy.payment_allocation_order,
        "gracePeriodConfiguration": policy.grace_period_configuration,
        "lateFeeConfiguration": policy.late_fee_configuration,
        "earlySettlementConfiguration": policy.early_settlement_configuration,
        "excessPaymentTreatment": policy.excess_payment_treatment,
        "restructuringPolicy": policy.restructuring_policy,
        "writeOffPolicy": policy.write_off_policy,
        "contractTemplateVersion": policy.contract_template_version,
        "effectiveDate": policy.effective_date.isoformat(),
    }


async def create_policy(
    db: AsyncSession, payload: LoanPolicyCreate, user: User
) -> LoanPolicyVersion:
    if payload.maximum_rate < payload.minimum_rate:
        raise ValueError("maximum rate must be greater than or equal to minimum rate")
    policy = LoanPolicyVersion(
        id=str(uuid4()),
        status="draft",
        created_by_user_id=user.id,
        **payload.model_dump(),
    )
    db.add(policy)
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=user.id,
            action="POLICY_CREATE",
            entity_name="loan_policy_versions",
            entity_id=policy.id,
            new_state_json=json.dumps(
                {"status": "draft", "version": policy.version_number}
            ),
        )
    )
    await db.flush()
    return policy


async def activate_policy(
    db: AsyncSession, policy_id: str, checker: User, reason: str
) -> LoanPolicyVersion:
    policy = (
        await db.execute(
            select(LoanPolicyVersion)
            .where(LoanPolicyVersion.id == policy_id)
            .with_for_update()
        )
    ).scalar_one_or_none()
    if policy is None:
        raise ValueError("Policy not found")
    if policy.status != "draft":
        raise ValueError("Only a draft policy may be activated")
    if policy.created_by_user_id == checker.id:
        raise PermissionError("Policy maker cannot approve the same policy")
    now = datetime.now(UTC)
    policy.status, policy.approved_by_user_id, policy.approved_at = (
        "active",
        checker.id,
        now,
    )
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=checker.id,
            action="POLICY_ACTIVATE",
            entity_name="loan_policy_versions",
            entity_id=policy.id,
            old_state_json='{"status":"draft"}',
            new_state_json=json.dumps(
                {"status": "active", "reason": reason, "approvedAt": now.isoformat()}
            ),
        )
    )
    await db.flush()
    return policy


async def retire_policy(
    db: AsyncSession, policy_id: str, user: User, reason: str
) -> LoanPolicyVersion:
    policy = (
        await db.execute(
            select(LoanPolicyVersion)
            .where(LoanPolicyVersion.id == policy_id)
            .with_for_update()
        )
    ).scalar_one_or_none()
    if policy is None or policy.status != "active":
        raise ValueError("Only an active policy may be retired")
    policy.status = "retired"
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=user.id,
            action="POLICY_RETIRE",
            entity_name="loan_policy_versions",
            entity_id=policy.id,
            old_state_json='{"status":"active"}',
            new_state_json=json.dumps({"status": "retired", "reason": reason}),
        )
    )
    await db.flush()
    return policy
