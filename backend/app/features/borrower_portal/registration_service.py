"""Transactional borrower registration review and account lifecycle logic."""

import json
import secrets
from datetime import UTC, datetime
from decimal import Decimal
from typing import Any
from uuid import uuid4

from sqlalchemy import and_, case, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.masking import mask_national_id as mask_national_id
from app.core.masking import mask_phone as mask_phone
from app.core.phone_numbers import normalize_ph_phone_number
from app.features.borrower_portal.models import (
    BorrowerAccount,
    BorrowerRefreshToken,
    BorrowerRegistrationAudit,
    BorrowerRegistrationRequest,
)
from app.features.borrower_portal.service import hash_secret
from app.features.borrowers.models import Borrower
from app.features.borrowers.schemas import BorrowerCreate
from app.features.borrowers.service import create_borrower
from app.features.loans.models import Loan
from app.features.users.models import User


class RegistrationConflict(Exception):
    pass


def _audit(
    db: AsyncSession,
    action: str,
    entity_type: str,
    entity_id: str,
    actor: User | None = None,
    metadata: dict[str, Any] | None = None,
) -> None:
    db.add(
        BorrowerRegistrationAudit(
            id=str(uuid4()),
            action=action,
            entity_type=entity_type,
            entity_id=entity_id,
            actor_user_id=actor.id if actor else None,
            metadata_json=json.dumps(metadata or {}, sort_keys=True),
        )
    )


async def submit(
    db: AsyncSession, payload: Any
) -> tuple[BorrowerRegistrationRequest, str]:
    now = datetime.now(UTC)

    # Protection: check if phone is already linked to an active BorrowerAccount
    acct = await db.scalar(
        select(BorrowerAccount).where(
            BorrowerAccount.phone_number_normalized == payload.phone_number
        )
    )
    if acct is not None:
        raise RegistrationConflict(
            "An account already exists for this mobile number. Please use Login or contact the lender."
        )

    existing = await db.scalar(
        select(BorrowerRegistrationRequest)
        .where(
            BorrowerRegistrationRequest.phone_number_normalized == payload.phone_number,
            BorrowerRegistrationRequest.status == "pending",
        )
        .order_by(BorrowerRegistrationRequest.submitted_at.desc())
        .limit(1)
    )
    if existing is not None:
        # A retry gets a fresh token without creating another pending application.
        raw_token = secrets.token_urlsafe(32)
        existing.status_token_hash = hash_secret(raw_token)
        existing.updated_at = now
        return existing, raw_token
    raw_token = secrets.token_urlsafe(32)
    request = BorrowerRegistrationRequest(
        id=str(uuid4()),
        first_name=payload.first_name.strip(),
        middle_name=payload.middle_name.strip() if payload.middle_name else None,
        last_name=payload.last_name.strip(),
        suffix=payload.suffix.strip() if payload.suffix else None,
        national_id=payload.national_id,
        phone_number=payload.phone_number,
        phone_number_normalized=payload.phone_number,
        date_of_birth=payload.date_of_birth,
        email=str(payload.email).lower() if payload.email else None,
        status="pending",
        status_token_hash=hash_secret(raw_token),
        privacy_accepted_at=now,
        terms_accepted_at=now,
        submitted_at=now,
        created_at=now,
        updated_at=now,
    )
    db.add(request)
    _audit(db, "REGISTRATION_SUBMITTED", "registration_request", request.id)
    await db.flush()
    return request, raw_token


async def status_for_token(db: AsyncSession, raw_token: str) -> tuple[str, str]:
    request = await db.scalar(
        select(BorrowerRegistrationRequest).where(
            BorrowerRegistrationRequest.status_token_hash == hash_secret(raw_token)
        )
    )
    if request is None:
        return "unknown", "Registration status is unavailable."
    status = request.status
    if status == "approved":
        account = await db.scalar(
            select(BorrowerAccount).where(
                BorrowerAccount.borrower_id == request.linked_borrower_id
            )
        )
        status = (
            "active" if account and account.account_status == "activated" else "approved"
        )
    messages = {
        "pending": "Your registration is pending review.",
        "approved": "Your registration is approved. Use your activation code to activate your account.",
        "active": "Your account is activated and ready for login.",
        "rejected": "Your registration was not approved. Contact the lender for assistance.",
        "cancelled": "This registration was cancelled.",
        "expired": "This registration has expired.",
    }
    return status, messages.get(status, "Registration status is unavailable.")


async def list_requests(
    db: AsyncSession, requested_status: str, offset: int, limit: int
) -> list[BorrowerRegistrationRequest]:
    result = await db.execute(
        select(BorrowerRegistrationRequest)
        .where(BorrowerRegistrationRequest.status == requested_status)
        .order_by(BorrowerRegistrationRequest.submitted_at)
        .offset(offset)
        .limit(limit)
    )
    return list(result.scalars())


async def get_locked(
    db: AsyncSession, request_id: str
) -> BorrowerRegistrationRequest | None:
    return await db.scalar(
        select(BorrowerRegistrationRequest)
        .where(BorrowerRegistrationRequest.id == request_id)
        .with_for_update()
    )


async def approve(
    db: AsyncSession,
    request_id: str,
    borrower_id: str,
    reviewer: User,
    notes: str | None,
) -> BorrowerAccount | None:
    item = await get_locked(db, request_id)
    if item is None:
        return None
    if item.status != "pending":
        raise RegistrationConflict("Registration request has already been reviewed")
    borrower = await db.scalar(
        select(Borrower)
        .where(Borrower.id == borrower_id, Borrower.status != "Deleted")
        .with_for_update()
    )
    if borrower is None or borrower.status not in {"Active", "Synced"}:
        raise RegistrationConflict(
            "Selected borrower is not eligible for portal access"
        )
    linked = await db.scalar(
        select(BorrowerAccount)
        .where(BorrowerAccount.borrower_id == borrower_id)
        .with_for_update()
    )
    phone_account = await db.scalar(
        select(BorrowerAccount)
        .where(BorrowerAccount.phone_number_normalized == item.phone_number_normalized)
        .with_for_update()
    )
    if linked is not None or phone_account is not None:
        raise RegistrationConflict("Borrower or phone number is already linked")
    now = datetime.now(UTC)
    account = BorrowerAccount(
        id=str(uuid4()),
        borrower_id=borrower.id,
        phone_number=item.phone_number_normalized,
        phone_number_normalized=item.phone_number_normalized,
        account_status="approved",
        created_at=now,
        updated_at=now,
    )
    db.add(account)
    (
        item.status,
        item.linked_borrower_id,
        item.reviewed_by_user_id,
        item.reviewed_at,
        item.review_notes,
    ) = "approved", borrower.id, reviewer.id, now, notes

    _audit(
        db,
        "REGISTRATION_APPROVED",
        "registration_request",
        item.id,
        reviewer,
        {"borrower_id": borrower.id},
    )
    _audit(
        db,
        "ACCOUNT_LINKED",
        "borrower_account",
        account.id,
        reviewer,
        {"borrower_id": borrower.id},
    )
    await db.flush()
    return account


async def create_and_approve(
    db: AsyncSession,
    request_id: str,
    national_id: str | None,
    reviewer: User,
    notes: str | None,
) -> BorrowerAccount | None:
    """Create a borrower from a locked request and approve it atomically."""
    item = await get_locked(db, request_id)
    if item is None:
        return None
    if item.status != "pending":
        raise RegistrationConflict("Registration request has already been reviewed")

    if (
        item.national_id
        and national_id
        and item.national_id.strip() != national_id.strip()
    ):
        raise RegistrationConflict(
            "National ID in registration request does not match review payload"
        )
    normalized_national_id = (item.national_id or national_id or "").strip()
    if len(normalized_national_id) < 4:
        raise RegistrationConflict(
            "National ID is required to create a borrower record"
        )
    conflict = await db.scalar(
        select(Borrower)
        .where(
            or_(
                Borrower.phone_normalized == item.phone_number_normalized,
                Borrower.national_id == normalized_national_id,
            )
        )
        .with_for_update()
    )
    if conflict is not None:
        raise RegistrationConflict(
            "Phone number or national ID already belongs to a borrower; link the existing record instead"
        )

    now = datetime.now(UTC)
    borrower = await create_borrower(
        db,
        BorrowerCreate(
            id=str(uuid4()),
            first_name=item.first_name,
            last_name=item.last_name,
            national_id=normalized_national_id,
            phone=item.phone_number_normalized,
            date_of_birth=item.date_of_birth,
            status="Active",
            created_at=now,
        ),
        reviewer,
    )
    _audit(
        db,
        "BORROWER_CREATED_FROM_REGISTRATION",
        "registration_request",
        item.id,
        reviewer,
        {"borrower_id": borrower.id},
    )
    return await approve(db, request_id, borrower.id, reviewer, notes)


async def reject(
    db: AsyncSession, request_id: str, reason: str, reviewer: User
) -> BorrowerRegistrationRequest | None:
    item = await get_locked(db, request_id)
    if item is None:
        return None
    if item.status != "pending":
        raise RegistrationConflict("Registration request has already been reviewed")
    item.status, item.rejection_reason, item.reviewed_by_user_id, item.reviewed_at = (
        "rejected",
        reason,
        reviewer.id,
        datetime.now(UTC),
    )
    _audit(db, "REGISTRATION_REJECTED", "registration_request", item.id, reviewer)
    await db.flush()
    return item


async def account_action(
    db: AsyncSession,
    account_id: str,
    action: str,
    reviewer: User,
    reason: str,
    borrower_id: str | None = None,
) -> BorrowerAccount | None:
    account = await db.scalar(
        select(BorrowerAccount)
        .where(BorrowerAccount.id == account_id)
        .with_for_update()
    )
    if account is None:
        return None
    now = datetime.now(UTC)
    if action == "relink":
        if account.account_status != "disabled" or borrower_id is None:
            raise RegistrationConflict("Only a disabled account can be safely relinked")
        borrower = await db.scalar(
            select(Borrower)
            .where(Borrower.id == borrower_id, Borrower.status != "Deleted")
            .with_for_update()
        )
        occupied = await db.scalar(
            select(BorrowerAccount).where(
                BorrowerAccount.borrower_id == borrower_id,
                BorrowerAccount.id != account.id,
            )
        )
        if borrower is None or occupied is not None:
            raise RegistrationConflict(
                "Selected borrower is not eligible or is already linked"
            )
        old_id, account.borrower_id = account.borrower_id, borrower_id
        _audit(
            db,
            "ACCOUNT_RELINKED",
            "borrower_account",
            account.id,
            reviewer,
            {"old_borrower_id": old_id, "borrower_id": borrower_id, "reason": reason},
        )
    else:
        transitions = {
            "suspend": ({"activated", "approved"}, "suspended"),
            "reactivate": ({"suspended"}, "activated"),
            "disable": ({"activated", "approved", "suspended"}, "disabled"),
        }
        allowed, target = transitions[action]
        if account.account_status not in allowed:
            raise RegistrationConflict(
                f"Account cannot be {action}ed from its current state"
            )
        account.account_status = target
        audit_action = {
            "suspend": "ACCOUNT_SUSPENDED",
            "reactivate": "ACCOUNT_REACTIVATED",
            "disable": "ACCOUNT_DISABLED",
        }[action]
        _audit(
            db,
            audit_action,
            "borrower_account",
            account.id,
            reviewer,
            {"reason": reason},
        )
    if action in {"suspend", "disable", "relink"}:
        await db.execute(
            update(BorrowerRefreshToken)
            .where(
                BorrowerRefreshToken.borrower_account_id == account.id,
                BorrowerRefreshToken.revoked_at.is_(None),
            )
            .values(revoked_at=now)
        )
    account.updated_at = now
    await db.flush()
    return account


async def find_possible_borrower_matches(
    db: AsyncSession, request: BorrowerRegistrationRequest
) -> list[dict[str, Any]]:
    """Search Borrower database for potential existing borrower matches using targeted candidate queries."""
    candidate_conditions = []

    # 1. Exact normalized phone candidate condition
    if request.phone_number_normalized:
        candidate_conditions.append(
            or_(
                Borrower.phone_normalized == request.phone_number_normalized,
                Borrower.phone == request.phone_number_normalized,
            )
        )

    # 2. Exact national ID candidate condition
    if request.national_id and request.national_id.strip():
        candidate_conditions.append(
            func.lower(Borrower.national_id) == request.national_id.strip().lower()
        )

    # 3. DOB + name candidate condition
    if request.date_of_birth and (request.first_name or request.last_name):
        name_conds = []
        if request.first_name:
            name_conds.append(func.lower(Borrower.first_name) == request.first_name.strip().lower())
        if request.last_name:
            name_conds.append(func.lower(Borrower.last_name) == request.last_name.strip().lower())
        candidate_conditions.append(
            and_(
                Borrower.date_of_birth == request.date_of_birth,
                or_(*name_conds),
            )
        )

    if not candidate_conditions:
        return []

    # Query targeted candidate borrowers only
    stmt = select(Borrower).where(
        Borrower.status != "Deleted",
        or_(*candidate_conditions),
    )
    res = await db.execute(stmt)
    borrowers = list(res.scalars())

    if not borrowers:
        return []

    borrower_ids = [b.id for b in borrowers]

    # Single bulk aggregation query for loan counts and active balances
    loans_stmt = select(
        Loan.borrower_id,
        func.count(Loan.id).label("total_loans"),
        func.count(
            case((Loan.status.in_(["Active", "Overdue"]), 1), else_=None)
        ).label("active_loans"),
        func.coalesce(
            func.sum(
                case(
                    (Loan.status.in_(["Active", "Overdue"]), Loan.outstanding_principal),
                    else_=Decimal("0.00"),
                )
            ),
            Decimal("0.00"),
        ).label("active_balance"),
    ).where(
        Loan.borrower_id.in_(borrower_ids)
    ).group_by(Loan.borrower_id)

    loans_res = await db.execute(loans_stmt)
    loan_stats = {
        row.borrower_id: {
            "total": row.total_loans,
            "active": row.active_loans,
            "balance": row.active_balance,
        }
        for row in loans_res
    }

    matches: list[dict[str, Any]] = []
    seen_ids: set[str] = set()

    for b in borrowers:
        if b.id in seen_ids:
            continue

        reason: str | None = None
        match_type: str | None = None
        norm_phone = b.phone_normalized or normalize_ph_phone_number(b.phone)

        # Classify candidate match
        if norm_phone == request.phone_number_normalized:
            reason = "Exact phone match"
            match_type = "exact_phone"
        elif request.national_id and b.national_id and b.national_id.strip().lower() == request.national_id.strip().lower():
            reason = "Exact national ID match"
            match_type = "exact_national_id"
        elif (
            b.date_of_birth == request.date_of_birth
            and (
                (request.first_name and b.first_name.strip().lower() == request.first_name.strip().lower())
                or (request.last_name and b.last_name.strip().lower() == request.last_name.strip().lower())
            )
        ):
            reason = "Matching name and date of birth"
            match_type = "name_dob"

        if reason and match_type:
            seen_ids.add(b.id)
            stats = loan_stats.get(b.id, {"total": 0, "active": 0, "balance": Decimal("0.00")})
            matches.append({
                "borrower_id": b.id,
                "full_name": f"{b.first_name} {b.last_name}".strip(),
                "masked_phone": mask_phone(norm_phone),
                "masked_national_id": mask_national_id(b.national_id),
                "existing_loans_count": stats["total"],
                "active_loans_count": stats["active"],
                "current_balance": f"{stats['balance']:.2f}",
                "match_reason": reason,
                "match_type": match_type,
            })

    return matches
