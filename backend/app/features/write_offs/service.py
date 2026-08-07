"""Append-only write-off and recovery commands."""

import json
from datetime import UTC, datetime, time
from decimal import Decimal
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.features.accounting.service import (
    post_journal,
    recovery_after_write_off_lines,
    write_off_lines,
)
from app.features.admin_assistant.models import AuditLog
from app.features.loans.models import Loan
from app.features.users.models import User
from app.features.write_offs.models import LoanWriteOff, WriteOffRecovery
from app.features.write_offs.schemas import RecoveryCreate, WriteOffCreate


async def write_off_loan(
    db: AsyncSession, loan_id: str, payload: WriteOffCreate, user: User
) -> LoanWriteOff:
    loan = await db.scalar(select(Loan).where(Loan.id == loan_id).with_for_update())
    if loan is None:
        raise ValueError("Loan not found")
    if loan.status not in {"Active", "Overdue", "Defaulted"}:
        raise ValueError("Loan is not eligible for write-off")
    if payload.amount != loan.outstanding_principal:
        raise ValueError("Write-off must equal the full outstanding principal")
    write_off = LoanWriteOff(
        id=str(uuid4()),
        loan_id=loan.id,
        approval_request_id=payload.approval_request_id,
        amount=payload.amount,
        effective_date=payload.effective_date,
        reason=payload.reason.strip(),
        written_off_by_user_id=user.id,
    )
    loan.outstanding_principal = Decimal("0.00")
    loan.status = "WrittenOff"
    db.add(write_off)
    posted_at = datetime.combine(payload.effective_date, time.min, UTC)
    await post_journal(
        db,
        actor=user,
        currency="PHP",
        posted_at=posted_at,
        source_type="loan_write_off",
        source_record_id=write_off.id,
        idempotency_key=f"loan-write-off:{write_off.id}",
        description=f"Loan {loan.id} principal write-off",
        lines=write_off_lines(payload.amount),
    )
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=user.id,
            action="WRITE_OFF_LOAN",
            entity_name="loan_write_off",
            entity_id=write_off.id,
            old_state_json=json.dumps({"outstandingPrincipal": str(payload.amount)}),
            new_state_json='{"outstandingPrincipal":"0.00","status":"WrittenOff"}',
        )
    )
    await db.flush()
    return write_off


async def record_recovery(
    db: AsyncSession, loan_id: str, payload: RecoveryCreate, user: User
) -> WriteOffRecovery:
    existing = await db.scalar(
        select(WriteOffRecovery).where(
            WriteOffRecovery.request_id == payload.request_id
        )
    )
    if existing is not None:
        if (
            existing.amount != payload.amount
            or existing.effective_date != payload.effective_date
        ):
            raise ValueError("Recovery request ID conflicts with existing data")
        return existing
    write_off = await db.scalar(
        select(LoanWriteOff)
        .options(selectinload(LoanWriteOff.recoveries))
        .where(LoanWriteOff.loan_id == loan_id)
        .with_for_update()
    )
    if write_off is None:
        raise ValueError("Written-off loan not found")
    recovered = sum((item.amount for item in write_off.recoveries), Decimal("0.00"))
    if recovered + payload.amount > write_off.amount:
        raise ValueError("Recovery exceeds the written-off principal")
    recovery = WriteOffRecovery(
        id=str(uuid4()),
        request_id=payload.request_id,
        write_off_id=write_off.id,
        amount=payload.amount,
        effective_date=payload.effective_date,
        note=payload.note,
        recorded_by_user_id=user.id,
    )
    db.add(recovery)
    await post_journal(
        db,
        actor=user,
        currency="PHP",
        posted_at=datetime.combine(payload.effective_date, time.min, UTC),
        source_type="write_off_recovery",
        source_record_id=recovery.id,
        idempotency_key=f"write-off-recovery:{payload.request_id}",
        request_id=payload.request_id,
        description=f"Recovery for written-off loan {loan_id}",
        lines=recovery_after_write_off_lines(payload.amount),
    )
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=user.id,
            action="RECORD_WRITE_OFF_RECOVERY",
            entity_name="write_off_recovery",
            entity_id=recovery.id,
            new_state_json=json.dumps(
                {"loanId": loan_id, "amount": str(payload.amount)}
            ),
        )
    )
    await db.flush()
    return recovery
