"""Borrower business logic and redacted audit logging."""

import json
from datetime import date
from typing import Literal
from uuid import uuid4

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.phone_numbers import normalize_ph_phone_number
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


async def check_borrower_identity(
    db: AsyncSession,
    first_name: str,
    last_name: str,
    national_id: str,
    phone: str,
    date_of_birth: date,
) -> tuple[Literal["available", "restore", "existing", "conflict"], str, str | None]:
    """Classify registration identity without exposing matching borrower PII."""
    normalized_phone = normalize_ph_phone_number(phone)
    result = await db.execute(
        select(Borrower).where(
            or_(
                Borrower.phone_normalized == normalized_phone,
                Borrower.national_id == national_id,
            )
        )
    )
    matches = list(result.scalars())
    if not matches:
        return "available", "Borrower identity is available", None

    exact = [
        item
        for item in matches
        if item.phone_normalized == normalized_phone and item.national_id == national_id
    ]
    if len(exact) == 1 and len(matches) == 1:
        borrower = exact[0]
        if (
            _normalized_name(borrower.first_name),
            _normalized_name(borrower.last_name),
        ) != (
            _normalized_name(first_name),
            _normalized_name(last_name),
        ):
            return (
                "conflict",
                "First or last name does not match the existing borrower identity",
                None,
            )
        if borrower.date_of_birth != date_of_birth:
            return (
                "conflict",
                "Date of birth does not match the existing borrower identity",
                None,
            )
        if borrower.status == "Deleted":
            return (
                "restore",
                "A deleted borrower with this identity already exists",
                borrower.id,
            )
        return "existing", "This borrower identity is already registered", borrower.id

    return (
        "conflict",
        "Phone number or national ID belongs to a different borrower",
        None,
    )


def _normalized_name(value: str) -> str:
    """Normalize harmless name casing and whitespace differences."""
    return " ".join(value.split()).casefold()


async def create_borrower(
    db: AsyncSession,
    payload: BorrowerCreate,
    user: User,
) -> Borrower:
    """Create a borrower or safely restore the same soft-deleted identity.

    A restore is allowed only when both canonical phone and national ID match
    one deleted record. Matching only one identifier is an identity conflict,
    not evidence that the records belong to the same person.
    """
    values = payload.model_dump(by_alias=False)
    normalized_phone = normalize_ph_phone_number(values["phone"])
    result = await db.execute(
        select(Borrower).where(
            Borrower.status == "Deleted",
            or_(
                Borrower.phone_normalized == normalized_phone,
                Borrower.national_id == values["national_id"],
            ),
        )
    )
    deleted_matches = list(result.scalars())
    exact_matches = [
        item
        for item in deleted_matches
        if item.phone_normalized == normalized_phone
        and item.national_id == values["national_id"]
        and item.date_of_birth == values["date_of_birth"]
        and _normalized_name(item.first_name) == _normalized_name(values["first_name"])
        and _normalized_name(item.last_name) == _normalized_name(values["last_name"])
    ]
    if deleted_matches and len(exact_matches) != 1:
        raise BorrowerIdentityConflictError(
            "Name, phone number, national ID, or date of birth does not match the deleted borrower"
        )
    if exact_matches:
        borrower = exact_matches[0]
        old_state = _audit_state(borrower)
        borrower.first_name = values["first_name"]
        borrower.last_name = values["last_name"]
        borrower.phone = values["phone"]
        borrower.national_id = values["national_id"]
        borrower.date_of_birth = values["date_of_birth"]
        borrower.status = (
            values["status"] if values["status"] != "Deleted" else "Active"
        )
        _add_audit_log(
            db,
            user,
            "RESTORE_BORROWER",
            borrower.id,
            old_state,
            _audit_state(borrower),
        )
        await db.flush()
        return borrower

    borrower = Borrower(
        **values,
        phone_normalized=normalized_phone,
    )
    db.add(borrower)
    _add_audit_log(
        db, user, "CREATE_BORROWER", borrower.id, None, _audit_state(borrower)
    )
    await db.flush()
    return borrower


class BorrowerIdentityConflictError(Exception):
    """Raised when supplied identifiers do not prove one deleted identity."""


async def update_borrower(
    db: AsyncSession,
    borrower: Borrower,
    payload: BorrowerUpdate,
    user: User,
) -> Borrower:
    """Apply borrower changes and stage a redacted audit entry."""
    old_state = _audit_state(borrower)
    values = payload.model_dump(exclude_unset=True, by_alias=False)
    for field, value in values.items():
        setattr(borrower, field, value)
    if "phone" in values:
        borrower.phone_normalized = normalize_ph_phone_number(values["phone"])
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
