"""Approved write-off and idempotent recovery endpoints."""

from fastapi import APIRouter, HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import selectinload

from app.core.authorization import require_owner
from app.core.dependencies import CurrentUser, DbSession
from app.features.write_offs import service
from app.features.write_offs.models import LoanWriteOff, WriteOffRecovery
from app.features.write_offs.schemas import (
    RecoveryCreate,
    RecoveryResponse,
    WriteOffCreate,
    WriteOffResponse,
)

router = APIRouter(prefix="/api/v1/loans/{loan_id}", tags=["Write-offs"])


@router.post("/write-off", response_model=WriteOffResponse, status_code=201)
async def execute_write_off(
    loan_id: str, payload: WriteOffCreate, db: DbSession, current_user: CurrentUser
) -> LoanWriteOff | None:
    require_owner(current_user)
    try:
        write_off = await service.write_off_loan(db, loan_id, payload, current_user)
        await db.commit()
    except PermissionError as error:
        await db.rollback()
        raise HTTPException(status_code=403, detail=str(error)) from error
    except ValueError as error:
        await db.rollback()
        raise HTTPException(
            status_code=404 if "not found" in str(error).lower() else 409,
            detail=str(error),
        ) from error
    except IntegrityError as error:
        await db.rollback()
        raise HTTPException(
            status_code=409, detail="Write-off already exists"
        ) from error
    result = await db.scalar(
        select(LoanWriteOff)
        .options(selectinload(LoanWriteOff.recoveries))
        .where(LoanWriteOff.id == write_off.id)
    )
    return result


@router.post("/recoveries", response_model=RecoveryResponse, status_code=201)
async def create_recovery(
    loan_id: str, payload: RecoveryCreate, db: DbSession, current_user: CurrentUser
) -> WriteOffRecovery:
    require_owner(current_user)
    try:
        recovery = await service.record_recovery(db, loan_id, payload, current_user)
        await db.commit()
        await db.refresh(recovery)
        return recovery
    except ValueError as error:
        await db.rollback()
        raise HTTPException(
            status_code=404 if "not found" in str(error).lower() else 409,
            detail=str(error),
        ) from error
    except IntegrityError as error:
        await db.rollback()
        raise HTTPException(
            status_code=409, detail="Recovery request conflicts"
        ) from error
