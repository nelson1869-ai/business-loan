"""Borrower business logic and redacted audit logging."""

import json
from uuid import uuid4

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.features.admin_assistant.models import AuditLog
from app.features.borrowers.models import Borrower
from app.features.borrowers.schemas import BorrowerCreate, BorrowerUpdate
from app.features.loans.models import Loan
from app.features.users.models import User


def _audit_state(borrower: Borrower) -> str:
    """Serialize a borrower state without exposing PII."""
    return json.dumps(
        {
            "id": borrower.id,
            "status": borrower.status,
            "firstName": "[REDACTED]",
            "lastName": "[REDACTED]",
            "nationalId": "[REDACTED]",
            "phone": "[REDACTED]",
        }
    )


def _add_audit_log(
    db: AsyncSession,
    user: User,
    action: str,
    borrower_id: str,
    old_state: str | None,
    new_state: str | None,
) -> None:
    """Stage an immutable, redacted audit record in the current transaction."""
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=user.id,
            action=action,
            entity_name="borrowers",
            entity_id=borrower_id,
            old_state_json=old_state,
            new_state_json=new_state,
        )
    )


async def list_borrowers(
    db: AsyncSession,
    status: str | None,
    offset: int,
    limit: int,
) -> tuple[list[Borrower], int]:
    """Return a filtered borrower page and total matching row count."""
    filters = [Borrower.status != "Deleted"]
    if status:
        filters.append(Borrower.status == status)
    total = await db.scalar(select(func.count()).select_from(Borrower).where(*filters))
    result = await db.execute(
        select(Borrower)
        .where(*filters)
        .order_by(Borrower.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    return list(result.scalars()), int(total or 0)


async def get_borrower(db: AsyncSession, borrower_id: str) -> Borrower | None:
    """Return a non-deleted borrower by ID."""
    result = await db.execute(
        select(Borrower).where(Borrower.id == borrower_id, Borrower.status != "Deleted")
    )
    return result.scalar_one_or_none()


async def create_borrower(
    db: AsyncSession,
    payload: BorrowerCreate,
    user: User,
) -> Borrower:
    """Create a borrower and its redacted audit entry atomically."""
    borrower = Borrower(**payload.model_dump(by_alias=False))
    db.add(borrower)
    _add_audit_log(
        db, user, "CREATE_BORROWER", borrower.id, None, _audit_state(borrower)
    )
    await db.flush()
    return borrower


async def update_borrower(
    db: AsyncSession,
    borrower: Borrower,
    payload: BorrowerUpdate,
    user: User,
) -> Borrower:
    """Apply borrower changes and stage a redacted audit entry."""
    old_state = _audit_state(borrower)
    for field, value in payload.model_dump(exclude_unset=True, by_alias=False).items():
        setattr(borrower, field, value)
    _add_audit_log(
        db,
        user,
        "UPDATE_BORROWER",
        borrower.id,
        old_state,
        _audit_state(borrower),
    )
    await db.flush()
    return borrower


class BorrowerHasOpenLoansError(Exception):
    """Raised when deletion would orphan an open lending account."""


async def delete_borrower(db: AsyncSession, borrower: Borrower, user: User) -> Borrower:
    """Soft-delete a borrower only when all lending accounts are closed."""
    open_loan_count = await db.scalar(
        select(func.count())
        .select_from(Loan)
        .where(
            Loan.borrower_id == borrower.id,
            Loan.status.not_in({"Paid", "Cancelled"}),
        )
    )
    if open_loan_count:
        raise BorrowerHasOpenLoansError(
            "Borrower cannot be deleted while loans remain open"
        )
    old_state = _audit_state(borrower)
    borrower.status = "Deleted"
    _add_audit_log(
        db,
        user,
        "DELETE_BORROWER",
        borrower.id,
        old_state,
        _audit_state(borrower),
    )
    await db.flush()
    return borrower
