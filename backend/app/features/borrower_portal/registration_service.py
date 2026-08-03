"""Transactional borrower registration review and account lifecycle logic."""

import json
import secrets
from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.features.borrower_portal.models import (
    BorrowerAccount,
    BorrowerInvitation,
    BorrowerOTP,
    BorrowerRefreshToken,
    BorrowerRegistrationAudit,
    BorrowerRegistrationRequest,
)
from app.features.borrower_portal.service import hash_secret
from app.features.borrowers.models import Borrower
from app.features.borrowers.schemas import BorrowerCreate
from app.features.borrowers.service import create_borrower
from app.features.users.models import User


class RegistrationConflict(Exception):
    pass


def _audit(
    db: AsyncSession,
    action: str,
    target_type: str,
    target_id: str,
    actor: User | None = None,
    metadata: dict[str, str] | None = None,
) -> None:
    db.add(
        BorrowerRegistrationAudit(
            id=str(uuid4()),
            actor_user_id=actor.id if actor else None,
            action=action,
            target_type=target_type,
            target_id=target_id,
            metadata_json=json.dumps(metadata or {}, sort_keys=True),
        )
    )


def mask_phone(phone: str) -> str:
    return f"{phone[:3]}•••••{phone[-3:]}" if len(phone) >= 7 else "••••"


def mask_national_id(national_id: str | None) -> str:
    if not national_id:
        return "Not provided"
    return f"{'•' * max(4, len(national_id) - 4)}{national_id[-4:]}"


async def submit(db: AsyncSession, payload) -> tuple[BorrowerRegistrationRequest, str]:
    now = datetime.now(UTC)
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
            "active" if account and account.account_status == "active" else "approved"
        )
    messages = {
        "pending": "Your registration is pending review.",
        "approved": "Your registration is approved. Verify your mobile number to continue.",
        "active": "Your account is active. Proceed to login.",
        "rejected": "Your registration was not approved. Contact the lender for assistance.",
        "cancelled": "This registration was cancelled.",
        "expired": "This registration has expired.",
    }
    return status, messages.get(status, "Registration status is unavailable.")


async def list_requests(
    db: AsyncSession, requested_status: str, offset: int, limit: int
):
    result = await db.execute(
        select(BorrowerRegistrationRequest)
        .where(BorrowerRegistrationRequest.status == requested_status)
        .order_by(BorrowerRegistrationRequest.submitted_at)
        .offset(offset)
        .limit(limit)
    )
    return list(result.scalars())


async def get_locked(db: AsyncSession, request_id: str):
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
):
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
    await db.execute(
        update(BorrowerInvitation)
        .where(
            BorrowerInvitation.borrower_id == borrower.id,
            BorrowerInvitation.used_at.is_(None),
        )
        .values(used_at=now)
    )
    await db.execute(
        update(BorrowerOTP)
        .where(
            BorrowerOTP.phone_number_normalized == item.phone_number_normalized,
            BorrowerOTP.used_at.is_(None),
        )
        .values(used_at=now)
    )
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
    national_id: str,
    reviewer: User,
    notes: str | None,
):
    """Create a borrower from a locked request and approve it atomically."""
    item = await get_locked(db, request_id)
    if item is None:
        return None
    if item.status != "pending":
        raise RegistrationConflict("Registration request has already been reviewed")

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


async def reject(db: AsyncSession, request_id: str, reason: str, reviewer: User):
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
):
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
            "suspend": ({"active", "approved"}, "suspended"),
            "reactivate": ({"suspended"}, "active"),
            "disable": ({"active", "approved", "suspended"}, "disabled"),
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
