"""Borrower portal business logic and security service."""

import hashlib
import hmac
import json
import logging
import secrets
from datetime import UTC, date, datetime, timedelta
from typing import Any
from uuid import uuid4

import jwt
from fastapi import HTTPException, status
from jwt.exceptions import PyJWTError
from sqlalchemy import func, or_, select, update
from sqlalchemy.engine import CursorResult
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.phone_numbers import normalize_ph_phone_number
from app.features.auth.service import (
    TokenValidationError,
    hash_password as hash_pin_bcrypt,
    verify_password as verify_pin_bcrypt,
)
from app.features.borrower_portal.models import (
    BorrowerAccount,
    BorrowerActivationCode,
    BorrowerDevice,
    BorrowerLoanRequest,
    BorrowerNotification,
    BorrowerPinReset,
    BorrowerRefreshToken,
    BorrowerRegistrationAudit,
    BorrowerRegistrationRequest,
)
from app.features.borrower_portal.schemas import (
    BorrowerAppAccessStatusResponse,
    BorrowerProfileResponse,
    EnableAppAccessResponse,
)
from app.features.borrowers import service as borrower_service
from app.features.borrowers.models import Borrower
from app.features.notifications.service import create_borrower_notification
from app.features.users.models import User

logger = logging.getLogger(__name__)



def hash_secret(secret_text: str) -> str:
    """Return a deterministic SHA-256 hex hash of an activation code, device ID, or token string."""
    return hashlib.sha256(secret_text.encode("utf-8")).hexdigest()


def hash_pin_secure(pin: str) -> str:
    """Hash a borrower PIN securely using bcrypt."""
    return hash_pin_bcrypt(pin)


def verify_pin_secure(pin: str, stored_hash: str | None) -> tuple[bool, bool]:
    """
    Verify borrower PIN against stored hash.
    Returns (is_valid, needs_upgrade).
    Supports bcrypt and automatic upgrade from legacy SHA-256.
    """
    if not stored_hash:
        return False, False
    if stored_hash.startswith("$2b$") or stored_hash.startswith("$2a$"):
        return verify_pin_bcrypt(pin, stored_hash), False
    # Legacy SHA-256 comparison fallback with automatic migration
    legacy_hash = hash_secret(pin)
    if hmac.compare_digest(stored_hash, legacy_hash):
        return True, True  # Valid and needs upgrade to bcrypt
    return False, False





def create_borrower_access_token(
    account: BorrowerAccount,
    settings: Settings | None = None,
) -> str:
    """Create a signed borrower JWT access token with audience boundary."""
    current_settings = settings or get_settings()
    now = datetime.now(UTC)
    payload: dict[str, Any] = {
        "sub": account.id,
        "aud": "borrower-app",
        "account_type": "borrower",
        "borrower_account_id": account.id,
        "borrower_id": account.borrower_id,
        "type": "access",
        "iat": now,
        "exp": now + timedelta(minutes=current_settings.access_token_expire_minutes),
        "jti": secrets.token_hex(16),
    }
    return jwt.encode(
        payload,
        current_settings.jwt_secret_key,
        algorithm=current_settings.jwt_algorithm,
    )


def verify_borrower_access_token(
    token: str,
    settings: Settings | None = None,
) -> dict[str, Any]:
    """Decode and strictly validate borrower JWT access claims."""
    current_settings = settings or get_settings()
    try:
        payload = jwt.decode(
            token,
            current_settings.jwt_secret_key,
            algorithms=[current_settings.jwt_algorithm],
            audience="borrower-app",
        )
    except PyJWTError as error:
        raise TokenValidationError("Invalid or expired borrower token") from error

    if (
        payload.get("type") != "access"
        or payload.get("account_type") != "borrower"
        or not payload.get("sub")
        or not payload.get("borrower_id")
    ):
        raise TokenValidationError("Token lacks required borrower authorization claims")
    return payload


async def rotate_borrower_refresh_token(
    db: AsyncSession,
    raw_refresh_token: str,
    settings: Settings | None = None,
) -> tuple[BorrowerAccount, str, str, int]:
    """Rotate borrower refresh token with automatic reuse detection."""
    current_settings = settings or get_settings()
    now = datetime.now(UTC)
    input_hash = hash_secret(raw_refresh_token)

    stmt = select(BorrowerRefreshToken).where(
        BorrowerRefreshToken.token_hash == input_hash
    )
    res = await db.execute(stmt)
    token_record = res.scalar_one_or_none()

    if token_record is None:
        raise ValueError("Invalid refresh token")

    # Reuse detection: if token was already revoked, invalidate all tokens for account
    if token_record.revoked_at is not None or token_record.expires_at <= now:
        await db.execute(
            update(BorrowerRefreshToken)
            .where(
                BorrowerRefreshToken.borrower_account_id
                == token_record.borrower_account_id
            )
            .values(revoked_at=now)
        )
        await db.flush()
        raise ValueError("Refresh token reuse detected; all sessions revoked")

    account = await db.get(BorrowerAccount, token_record.borrower_account_id)
    if account is None or account.account_status in ("suspended", "disabled"):
        raise ValueError("Borrower account is inactive")

    # Enforce device trust and revocation check during refresh-token rotation
    if token_record.device_id:
        device = await db.get(BorrowerDevice, token_record.device_id)
        if device is None:
            dev_stmt = select(BorrowerDevice).where(
                BorrowerDevice.borrower_account_id == account.id,
                BorrowerDevice.device_identifier_hash == hash_secret(token_record.device_id),
            )
            dev_res = await db.execute(dev_stmt)
            device = dev_res.scalar_one_or_none()

        if device is None or not device.is_trusted or not device.is_active or device.revoked_at is not None:
            raise ValueError("Device is untrusted or revoked. Re-authentication required.")

    # Revoke current refresh token
    token_record.revoked_at = now

    # Issue new token pair
    access_token = create_borrower_access_token(account, current_settings)
    new_raw_refresh = secrets.token_urlsafe(32)
    new_refresh_record = BorrowerRefreshToken(
        id=secrets.token_hex(18),
        borrower_account_id=account.id,
        token_hash=hash_secret(new_raw_refresh),
        device_id=token_record.device_id,
        expires_at=now + timedelta(days=current_settings.refresh_token_expire_days),
        created_at=now,
    )
    db.add(new_refresh_record)
    await db.flush()

    expires_in_sec = current_settings.access_token_expire_minutes * 60
    return account, access_token, new_raw_refresh, expires_in_sec


async def revoke_borrower_refresh_token(
    db: AsyncSession,
    raw_refresh_token: str,
) -> None:
    """Revoke a specific refresh token during logout."""
    now = datetime.now(UTC)
    token_hash = hash_secret(raw_refresh_token)
    stmt = select(BorrowerRefreshToken).where(
        BorrowerRefreshToken.token_hash == token_hash
    )
    res = await db.execute(stmt)
    record = res.scalar_one_or_none()
    if record is not None and record.revoked_at is None:
        record.revoked_at = now
        await db.flush()


async def get_borrower_profile(
    db: AsyncSession,
    current_account: BorrowerAccount,
) -> BorrowerProfileResponse:
    """Fetch borrower profile details for an active borrower account."""
    borrower = await borrower_service.get_borrower(db, current_account.borrower_id)
    if borrower is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Borrower profile record not found",
        )

    return BorrowerProfileResponse(
        borrower_account_id=current_account.id,
        borrower_id=current_account.borrower_id,
        first_name=borrower.first_name,
        last_name=borrower.last_name,
        phone_number=current_account.phone_number_normalized
        or current_account.phone_number,
        account_status=current_account.account_status,
        created_at=current_account.created_at,
    )


# ── Single-Owner Registration, Activation & Loan Request Services ────────────

from app.features.borrower_portal.models import (
    BorrowerActivationCode,
    BorrowerLoanRequest,
)
from app.features.borrower_portal.schemas import (
    BorrowerActivationRequest,
    BorrowerLoanRequestResponse,
    BorrowerLoanRequestSubmit,
    BorrowerPINLoginRequest,
    BorrowerRegistrationItemResponse,
    BorrowerRegistrationSubmitRequest,
    OwnerApproveRegistrationResponse,
)
from app.features.loans.models import Loan
from decimal import Decimal


async def submit_borrower_registration(
    db: AsyncSession,
    payload: BorrowerRegistrationSubmitRequest,
) -> BorrowerRegistrationRequest:
    """Public sign-up endpoint for new borrowers (Status = Pending)."""
    norm_phone = normalize_ph_phone_number(payload.phone_number)
    now = datetime.now(UTC)

    # Check if there is already an active borrower account with this phone
    existing_acct = await db.execute(
        select(BorrowerAccount).where(
            BorrowerAccount.phone_number_normalized == norm_phone
        )
    )
    if existing_acct.scalar_one_or_none() is not None:
        raise ValueError("An account with this mobile number already exists")

    # Check if national ID already registered
    existing_b = await db.execute(
        select(Borrower).where(Borrower.national_id == payload.national_id)
    )
    if existing_b.scalar_one_or_none() is not None:
        raise ValueError("A borrower with this Government ID already exists")

    dob = date.fromisoformat(payload.date_of_birth)
    pin_hash = hash_pin_secure(payload.pin_or_password)

    req = BorrowerRegistrationRequest(
        id=secrets.token_hex(18),
        first_name=payload.first_name,
        last_name=payload.last_name,
        national_id=payload.national_id,
        phone_number=payload.phone_number,
        phone_number_normalized=norm_phone,
        date_of_birth=dob,
        address=payload.address,
        id_photo_url=payload.id_photo_url,
        selfie_url=payload.selfie_url,
        pin_hash=pin_hash,
        status="pending",
        status_token_hash=secrets.token_hex(32),
        privacy_accepted_at=now,
        terms_accepted_at=now,
        submitted_at=now,
        created_at=now,
        updated_at=now,
    )
    db.add(req)
    await db.flush()
    return req


async def approve_borrower_registration(
    db: AsyncSession,
    registration_id: str,
    owner_user: User,
) -> OwnerApproveRegistrationResponse:
    """Owner endpoint to approve a pending registration, create Borrower + BorrowerAccount, and generate a 6-digit Activation Code."""
    now = datetime.now(UTC)
    res = await db.execute(
        select(BorrowerRegistrationRequest).where(
            BorrowerRegistrationRequest.id == registration_id
        )
    )
    reg = res.scalar_one_or_none()
    if reg is None:
        raise ValueError("Registration request not found")
    if reg.status not in ("Pending", "pending"):
        raise ValueError("Only pending registrations can be approved")

    # 1. Create or link Borrower record
    borrower = Borrower(
        id=secrets.token_hex(18),
        first_name=reg.first_name,
        last_name=reg.last_name,
        national_id=reg.national_id or f"NAT-{secrets.token_hex(6)}",
        phone=reg.phone_number,
        phone_normalized=reg.phone_number_normalized,
        date_of_birth=reg.date_of_birth,
        status="Active",
        created_at=now,
    )
    db.add(borrower)
    await db.flush()

    # 2. Create BorrowerAccount (Status = Approved, awaiting activation code redemption)
    account = BorrowerAccount(
        id=secrets.token_hex(18),
        borrower_id=borrower.id,
        phone_number=reg.phone_number,
        phone_number_normalized=reg.phone_number_normalized,
        account_status="approved",
        password_hash=reg.pin_hash,
        address=reg.address,
        id_photo_url=reg.id_photo_url,
        selfie_url=reg.selfie_url,
        created_at=now,
        updated_at=now,
    )
    db.add(account)

    # 3. Update registration request
    reg.status = "approved"
    reg.linked_borrower_id = borrower.id
    reg.reviewed_at = now
    reg.reviewed_by_user_id = owner_user.id

    # 4. Generate 6-digit Activation Code via canonical generator
    activation, raw_code = await generate_new_activation_code(
        db, account.id, owner_user
    )

    await create_borrower_notification(
        db,
        borrower_id=borrower.id,
        notification_type="registration_approved",
        title="Registration Approved",
        message="Your borrower registration has been approved. Contact owner for your activation code.",
        entity_type="registration",
        entity_id=reg.id,
        metadata={"registration_id": reg.id},
        deduplication_key=f"registration_approved:{borrower.id}",
    )

    await db.flush()

    return OwnerApproveRegistrationResponse(
        registration_id=reg.id,
        borrower_id=borrower.id,
        borrower_account_id=account.id,
        activation_code=raw_code,
        expires_at=activation.expires_at,
    )


def _audit_portal_event(
    db: AsyncSession,
    action: str,
    target_type: str,
    target_id: str,
    actor: User | None = None,
    metadata: dict[str, Any] | None = None,
) -> None:
    """Record PII-minimal immutable security audit event."""
    db.add(
        BorrowerRegistrationAudit(
            id=str(uuid4()),
            action=action,
            target_type=target_type,
            target_id=target_id,
            actor_user_id=actor.id if actor else None,
            metadata_json=json.dumps(metadata or {}, sort_keys=True),
            created_at=datetime.now(UTC),
        )
    )


async def enable_existing_borrower_app_access(
    db: AsyncSession,
    borrower_id: str,
    owner_user: User,
) -> EnableAppAccessResponse:
    """Owner action to enable Borrower App access for an existing Borrower record."""
    now = datetime.now(UTC)
    borrower = await db.scalar(
        select(Borrower)
        .where(Borrower.id == borrower_id, Borrower.status != "Deleted")
        .with_for_update()
    )
    if borrower is None:
        raise ValueError("Borrower not found")

    # Check whether BorrowerAccount already exists for borrower_id
    existing_account = await db.scalar(
        select(BorrowerAccount)
        .where(BorrowerAccount.borrower_id == borrower_id)
        .with_for_update()
    )
    if existing_account is not None:
        if existing_account.account_status in ("approved", "activated"):
            raise ValueError("Borrower app access is already enabled for this borrower.")
        else:
            raise ValueError(
                f"Account is currently {existing_account.account_status}. Use account management actions instead."
            )

    # Normalize borrower phone
    norm_phone = normalize_ph_phone_number(borrower.phone)

    # Check for conflicts with another account using the same normalized phone number
    phone_conflict = await db.scalar(
        select(BorrowerAccount)
        .where(BorrowerAccount.phone_number_normalized == norm_phone)
        .with_for_update()
    )
    if phone_conflict is not None:
        raise ValueError("Phone number is already linked to another borrower account")

    account = BorrowerAccount(
        id=str(uuid4()),
        borrower_id=borrower.id,
        phone_number=norm_phone,
        phone_number_normalized=norm_phone,
        account_status="approved",
        created_at=now,
        updated_at=now,
    )
    db.add(account)
    await db.flush()

    # Generate 6-digit activation code
    activation, raw_code = await generate_new_activation_code(db, account.id, owner_user)

    _audit_portal_event(
        db,
        "OWNER_ENABLED_BORROWER_APP_ACCESS",
        "borrower_account",
        account.id,
        owner_user,
        {"borrower_id": borrower.id},
    )
    await db.flush()

    return EnableAppAccessResponse(
        borrower_id=borrower.id,
        borrower_account_id=account.id,
        account_status=account.account_status,
        activation_code=raw_code,
        expires_at=activation.expires_at,
    )


async def get_borrower_app_access_status(
    db: AsyncSession,
    borrower_id: str,
) -> BorrowerAppAccessStatusResponse:
    """Owner endpoint to query borrower app access status. NEVER returns raw activation code."""
    now = datetime.now(UTC)
    borrower = await db.scalar(
        select(Borrower).where(Borrower.id == borrower_id)
    )
    if borrower is None:
        raise ValueError("Borrower not found")

    account = await db.scalar(
        select(BorrowerAccount).where(BorrowerAccount.borrower_id == borrower_id)
    )
    if account is None:
        return BorrowerAppAccessStatusResponse(
            has_account=False,
            account_id=None,
            account_status=None,
            phone_number=borrower.phone,
            activation_pending=False,
            activation_expires_at=None,
            trusted_devices_count=0,
            last_login_at=None,
            can_regenerate_activation_code=False,
        )

    # Check active unexpired activation code
    stmt = (
        select(BorrowerActivationCode)
        .where(
            BorrowerActivationCode.borrower_account_id == account.id,
            BorrowerActivationCode.used_at.is_(None),
        )
        .order_by(BorrowerActivationCode.created_at.desc())
    )
    res_code = await db.execute(stmt)
    code_rec = res_code.scalar_one_or_none()

    activation_pending = code_rec is not None and code_rec.expires_at > now and account.account_status in ("approved", "pending")
    activation_expires_at = code_rec.expires_at if (code_rec is not None and code_rec.expires_at > now) else None

    # Count trusted devices
    devices_res = await db.execute(
        select(func.count(BorrowerDevice.id)).where(
            BorrowerDevice.borrower_account_id == account.id,
            BorrowerDevice.is_trusted.is_(True),
            BorrowerDevice.is_active.is_(True),
        )
    )
    trusted_count = devices_res.scalar_one() or 0

    return BorrowerAppAccessStatusResponse(
        has_account=True,
        account_id=account.id,
        account_status=account.account_status,
        phone_number=account.phone_number,
        activation_pending=activation_pending,
        activation_expires_at=activation_expires_at,
        trusted_devices_count=trusted_count,
        last_login_at=account.last_login_at or account.last_successful_login,
        can_regenerate_activation_code=account.account_status in ("approved", "pending", "activated"),
    )


async def generate_new_activation_code(
    db: AsyncSession,
    account_id: str | BorrowerAccount,
    owner_user: User,
) -> tuple[BorrowerActivationCode, str]:
    """Owner endpoint to invalidate prior code and generate a fresh 6-digit Activation Code."""
    now = datetime.now(UTC)
    if isinstance(account_id, BorrowerAccount):
        account = account_id
    else:
        res = await db.execute(
            select(BorrowerAccount).where(BorrowerAccount.id == account_id)
        )
        account = res.scalar_one_or_none()
        if account is None:
            raise ValueError("Borrower account not found")

    # Revoke prior unused codes
    await db.execute(
        update(BorrowerActivationCode)
        .where(
            BorrowerActivationCode.borrower_account_id == account.id,
            BorrowerActivationCode.used_at.is_(None),
        )
        .values(used_at=now)
    )

    raw_code = f"{secrets.randbelow(1000000):06d}"
    code_hash = hash_secret(raw_code)
    expires_at = now + timedelta(hours=24)

    borrower_id = getattr(account, "borrower_id", None)
    activation = BorrowerActivationCode(
        id=secrets.token_hex(18),
        borrower_id=borrower_id,
        borrower_account_id=account.id,
        code_hash=code_hash,
        expires_at=expires_at,
        attempts=0,
        max_attempts=5,
        created_by_user_id=owner_user.id,
        created_at=now,
    )
    db.add(activation)
    await db.flush()

    # If account was Pending/Approved, ensure status is Approved
    if getattr(account, "account_status", "approved") in ("pending", "approved"):
        account.account_status = "approved"

    _audit_portal_event(
        db,
        "OWNER_REGENERATED_ACTIVATION_CODE",
        "borrower_activation_code",
        activation.id,
        owner_user,
        {"borrower_id": borrower_id, "borrower_account_id": account.id},
    )

    return activation, raw_code


async def verify_activation_code_and_activate(
    db: AsyncSession,
    payload: BorrowerActivationRequest,
    client_ip: str | None = None,
) -> tuple[BorrowerAccount, str, str, int]:
    """Redeem 6-digit Activation Code, enforce PIN creation if missing, set status to Activated, and issue JWT token pair."""
    now = datetime.now(UTC)
    norm_phone = normalize_ph_phone_number(payload.phone_number)
    raw_phone = payload.phone_number.strip()

    res = await db.execute(
        select(BorrowerAccount).where(
            or_(
                BorrowerAccount.phone_number_normalized == norm_phone,
                BorrowerAccount.phone_number_normalized == raw_phone,
                BorrowerAccount.phone_number == raw_phone,
                BorrowerAccount.phone_number == norm_phone,
            )
        )
    )
    account = res.scalar_one_or_none()
    if account is None:
        raise ValueError("Borrower account not found for this mobile number")

    if account.account_status in ("suspended", "disabled"):
        raise ValueError(f"Account is currently {account.account_status}")

    # Fetch active unexpired activation code for this account
    code_hash = hash_secret(payload.activation_code)
    stmt = (
        select(BorrowerActivationCode)
        .where(
            BorrowerActivationCode.borrower_account_id == account.id,
            BorrowerActivationCode.used_at.is_(None),
        )
        .order_by(BorrowerActivationCode.created_at.desc())
    )
    res_code = await db.execute(stmt)
    code_rec = res_code.scalar_one_or_none()

    if code_rec is None or code_rec.expires_at < now:
        raise ValueError("Activation code is invalid or has expired")

    if code_rec.attempts >= code_rec.max_attempts:
        raise ValueError("Maximum activation attempts exceeded. Contact owner for a new code.")

    if code_rec.code_hash != code_hash:
        code_rec.attempts += 1
        await db.flush()
        remaining = code_rec.max_attempts - code_rec.attempts
        raise ValueError(f"Incorrect activation code. {remaining} attempt(s) remaining.")

    # Correction 1 & 13: Enforce PIN Creation if borrower has no PIN set yet
    if account.password_hash is None:
        if not payload.new_pin or not payload.confirm_pin:
            raise ValueError("PIN creation is required upon activation. Please enter and confirm your new PIN.")
        if payload.new_pin != payload.confirm_pin:
            raise ValueError("PIN and confirm PIN do not match.")
        if len(payload.new_pin) < 4:
            raise ValueError("PIN must be at least 4 digits.")
        account.password_hash = hash_pin_secure(payload.new_pin)
    elif payload.new_pin:
        if payload.new_pin != payload.confirm_pin:
            raise ValueError("PIN and confirm PIN do not match.")
        account.password_hash = hash_pin_secure(payload.new_pin)

    # Mark code as redeemed
    code_rec.used_at = now
    code_rec.activated_device_id = payload.device_identifier
    code_rec.activated_ip = client_ip

    # Set account status to Activated
    account.account_status = "activated"
    account.phone_verified_at = now
    account.updated_at = now

    # Correction 10 & 13: Register & trust activating device
    device_hash = hash_secret(payload.device_identifier)
    dev_stmt = select(BorrowerDevice).where(
        BorrowerDevice.borrower_account_id == account.id,
        BorrowerDevice.device_identifier_hash == device_hash,
    )
    dev_res = await db.execute(dev_stmt)
    device = dev_res.scalar_one_or_none()
    if device is None:
        device = BorrowerDevice(
            id=secrets.token_hex(18),
            borrower_account_id=account.id,
            device_identifier_hash=device_hash,
            platform=payload.platform or "android",
            push_token=payload.push_token,
            first_seen_at=now,
            last_seen_at=now,
            is_active=True,
            is_trusted=True,
            created_at=now,
            updated_at=now,
        )
        db.add(device)
    else:
        device.is_active = True
        device.is_trusted = True
        device.revoked_at = None
        device.last_seen_at = now
        if payload.push_token:
            device.push_token = payload.push_token
            device.push_token_updated_at = now
    await db.flush()

    _audit_portal_event(
        db,
        "BORROWER_APP_ACTIVATED",
        "borrower_account",
        account.id,
        metadata={"borrower_id": account.borrower_id},
    )

    await create_borrower_notification(
        db,
        borrower_id=account.borrower_id,
        notification_type="account_activated",
        title="Account Activated",
        message="Your borrower account has been successfully activated.",
        entity_type="borrower_account",
        entity_id=account.id,
        deduplication_key=f"account_activated:{account.id}",
    )

    # Issue tokens
    settings = get_settings()
    access_token = create_borrower_access_token(account, settings)
    raw_refresh = secrets.token_urlsafe(32)
    refresh_record = BorrowerRefreshToken(
        id=secrets.token_hex(18),
        borrower_account_id=account.id,
        token_hash=hash_secret(raw_refresh),
        device_id=device.id,
        expires_at=now + timedelta(days=settings.refresh_token_expire_days),
        created_at=now,
    )
    db.add(refresh_record)
    await db.flush()

    expires_in_sec = settings.access_token_expire_minutes * 60
    return account, access_token, raw_refresh, expires_in_sec


async def login_borrower_with_pin(
    db: AsyncSession,
    payload: BorrowerPINLoginRequest,
) -> tuple[BorrowerAccount, str, str, int]:
    """PIN / Password login endpoint for borrowers (only Activated status permitted)."""
    now = datetime.now(UTC)
    norm_phone = normalize_ph_phone_number(payload.phone_number)

    res = await db.execute(
        select(BorrowerAccount).where(
            BorrowerAccount.phone_number_normalized == norm_phone
        )
    )
    account = res.scalar_one_or_none()
    if account is None:
        raise ValueError("Invalid phone number or PIN")

    # Check lock status
    if account.locked_until and account.locked_until > now:
        raise ValueError("Account is locked due to multiple failed attempts. Try again later or contact owner.")

    if account.account_status != "activated":
        raise ValueError(
            f"Account status is '{account.account_status}'. Only activated accounts may log in."
        )

    is_valid, needs_upgrade = verify_pin_secure(payload.pin_or_password, account.password_hash)
    if not is_valid:
        account.failed_login_attempts = (account.failed_login_attempts or 0) + 1
        account.last_failed_login = now
        if account.failed_login_attempts >= 10:
            account.locked_until = now + timedelta(days=3650)  # Owner reset required
        elif account.failed_login_attempts >= 5:
            account.locked_until = now + timedelta(minutes=15)  # 15 min cooldown
        account.updated_at = now
        await db.commit()
        raise ValueError("Invalid phone number or PIN")

    # Successful authentication
    account.failed_login_attempts = 0
    account.locked_until = None
    account.last_login_at = now
    account.last_successful_login = now
    if needs_upgrade:
        account.password_hash = hash_pin_secure(payload.pin_or_password)
    account.updated_at = now
    await db.flush()

    # Trusted device verification
    device_hash = hash_secret(payload.device_identifier)
    dev_stmt = select(BorrowerDevice).where(
        BorrowerDevice.borrower_account_id == account.id,
        BorrowerDevice.device_identifier_hash == device_hash,
    )
    dev_res = await db.execute(dev_stmt)
    device = dev_res.scalar_one_or_none()
    if device is None:
        device = BorrowerDevice(
            id=secrets.token_hex(18),
            borrower_account_id=account.id,
            device_identifier_hash=device_hash,
            platform="android",
            first_seen_at=now,
            last_seen_at=now,
            is_active=True,
            is_trusted=False,
            created_at=now,
            updated_at=now,
        )
        db.add(device)
        await db.commit()
        raise ValueError("Untrusted device. Contact owner for device approval or use a fresh 6-digit activation code.")

    if device.revoked_at is not None or not device.is_active:
        raise ValueError("This device registration has been revoked. Contact owner.")

    if not device.is_trusted:
        raise ValueError("Untrusted device. Contact owner for device approval or use a fresh 6-digit activation code.")

    device.last_seen_at = now
    await db.flush()

    settings = get_settings()
    access_token = create_borrower_access_token(account, settings)
    raw_refresh = secrets.token_urlsafe(32)
    refresh_record = BorrowerRefreshToken(
        id=secrets.token_hex(18),
        borrower_account_id=account.id,
        token_hash=hash_secret(raw_refresh),
        device_id=device.id,
        expires_at=now + timedelta(days=settings.refresh_token_expire_days),
        created_at=now,
    )
    db.add(refresh_record)
    await db.flush()

    expires_in_sec = settings.access_token_expire_minutes * 60
    return account, access_token, raw_refresh, expires_in_sec


async def submit_borrower_loan_request(
    db: AsyncSession,
    current_account: BorrowerAccount,
    payload: BorrowerLoanRequestSubmit,
) -> BorrowerLoanRequest:
    """Borrower endpoint to submit a new loan request."""
    now = datetime.now(UTC)

    # Check for active submitted request awaiting review
    existing_pending = await db.scalar(
        select(BorrowerLoanRequest).where(
            BorrowerLoanRequest.borrower_id == current_account.borrower_id,
            BorrowerLoanRequest.status.in_(["submitted", "pending"]),
        )
    )
    if existing_pending is not None:
        raise ValueError(
            "DUPLICATE_PENDING_LOAN_REQUEST: You already have a loan request awaiting review."
        )

    req = BorrowerLoanRequest(
        id=secrets.token_hex(18),
        borrower_id=current_account.borrower_id,
        requested_amount=Decimal(payload.requested_amount),
        requested_term_months=payload.requested_term_months,
        requested_payment_frequency=payload.requested_payment_frequency,
        requested_repayment_structure=payload.requested_repayment_structure,
        purpose=payload.purpose,
        status="submitted",
        created_at=now,
        updated_at=now,
    )
    db.add(req)

    await create_borrower_notification(
        db,
        borrower_id=current_account.borrower_id,
        notification_type="loan_request_submitted",
        title="Loan Request Submitted",
        message=f"Your loan request for ₱{req.requested_amount:,.2f} was submitted for owner review.",
        entity_type="loan_request",
        entity_id=req.id,
        metadata={"request_id": req.id},
        deduplication_key=f"loan_request_submitted:{req.id}",
    )

    await db.flush()
    return req


async def list_borrower_loan_requests(
    db: AsyncSession,
    current_account: BorrowerAccount,
) -> list[BorrowerLoanRequest]:
    """Fetch loan request history for current borrower."""
    stmt = (
        select(BorrowerLoanRequest)
        .where(BorrowerLoanRequest.borrower_id == current_account.borrower_id)
        .order_by(BorrowerLoanRequest.created_at.desc())
    )
    res = await db.execute(stmt)
    return list(res.scalars())


async def review_borrower_loan_request(
    db: AsyncSession,
    request_id: str,
    action: str,
    owner_notes: str | None,
    owner_user: User,
) -> BorrowerLoanRequest:
    """Owner endpoint to approve or decline a borrower loan request."""
    now = datetime.now(UTC)
    res = await db.execute(
        select(BorrowerLoanRequest).where(BorrowerLoanRequest.id == request_id)
    )
    req = res.scalar_one_or_none()
    if req is None:
        raise ValueError("Borrower loan request not found")

    if action == "approve":
        req.status = "approved"
    elif action == "decline":
        req.status = "declined"
    else:
        raise ValueError("Invalid review action")

    req.owner_notes = owner_notes
    req.reviewed_at = now
    req.updated_at = now

    notif_type = "loan_request_approved" if action == "approve" else "loan_request_declined"
    title = "Loan Request Approved" if action == "approve" else "Loan Request Declined"
    msg = (
        f"Your loan request for ₱{req.requested_amount:,.2f} has been approved."
        if action == "approve"
        else f"Your loan request for ₱{req.requested_amount:,.2f} was declined."
    )
    await create_borrower_notification(
        db,
        borrower_id=req.borrower_id,
        notification_type=notif_type,
        title=title,
        message=msg,
        entity_type="loan_request",
        entity_id=req.id,
        metadata={"request_id": req.id},
        deduplication_key=f"{notif_type}:{req.id}",
    )

    await db.flush()
    return req


async def confirm_borrower_pin(
    db: AsyncSession,
    current_account: BorrowerAccount,
    pin: str,
) -> bool:
    """Verify borrower PIN post-activation to confirm registration PIN accuracy."""
    is_valid, needs_upgrade = verify_pin_secure(pin, current_account.password_hash)
    if not is_valid:
        raise ValueError("PIN confirmation failed. PIN does not match.")
    if needs_upgrade:
        current_account.password_hash = hash_pin_secure(pin)
        await db.flush()
    return True


async def request_pin_reset(
    db: AsyncSession,
    phone_number: str,
) -> tuple[bool, str]:
    """Request a PIN reset code without leaking whether account exists."""
    try:
        norm_phone = normalize_ph_phone_number(phone_number)
    except ValueError:
        return True, "If the account exists, the owner has been notified of your PIN reset request."

    res = await db.execute(
        select(BorrowerAccount).where(
            BorrowerAccount.phone_number_normalized == norm_phone
        )
    )
    account = res.scalar_one_or_none()
    if account is not None:
        now = datetime.now(UTC)
        audit = BorrowerRegistrationAudit(
            id=secrets.token_hex(18),
            actor_user_id=None,
            action="forgot_pin_requested",
            target_type="borrower_account",
            target_id=account.id,
            metadata_json=f'{{"phone":"{norm_phone}"}}',
            created_at=now,
        )
        db.add(audit)
        await create_borrower_notification(
            db,
            borrower_id=account.borrower_id,
            notification_type="pin_reset_requested",
            title="PIN Reset Requested",
            message="A PIN reset request was submitted. Contact owner to obtain your 6-digit reset code.",
            entity_type="borrower_account",
            entity_id=account.id,
            deduplication_key=f"pin_reset_requested:{account.id}:{now.isoformat()}",
        )
        await db.flush()

    return True, "If the account exists, the owner has been notified of your PIN reset request."


async def issue_pin_reset_code(
    db: AsyncSession,
    account_id: str,
    owner_user: User,
) -> tuple[BorrowerPinReset, str]:
    """Owner endpoint to generate a 6-digit PIN reset code for a borrower account."""
    now = datetime.now(UTC)
    account = await db.get(BorrowerAccount, account_id)
    if account is None:
        raise ValueError("Borrower account not found")

    # Invalidate prior unused reset codes
    await db.execute(
        update(BorrowerPinReset)
        .where(
            BorrowerPinReset.borrower_account_id == account.id,
            BorrowerPinReset.used_at.is_(None),
        )
        .values(used_at=now)
    )

    raw_code = f"{secrets.randbelow(1000000):06d}"
    code_hash = hash_secret(raw_code)
    expires_at = now + timedelta(hours=24)

    reset_rec = BorrowerPinReset(
        id=secrets.token_hex(18),
        borrower_account_id=account.id,
        code_hash=code_hash,
        expires_at=expires_at,
        attempts=0,
        max_attempts=5,
        created_by_user_id=owner_user.id,
        created_at=now,
    )
    db.add(reset_rec)
    audit = BorrowerRegistrationAudit(
        id=secrets.token_hex(18),
        actor_user_id=owner_user.id,
        action="pin_reset_code_issued",
        target_type="borrower_account",
        target_id=account.id,
        created_at=now,
    )
    db.add(audit)
    await db.flush()
    return reset_rec, raw_code


async def redeem_pin_reset_code(
    db: AsyncSession,
    phone_number: str,
    reset_code: str,
    new_pin: str,
) -> bool:
    """Redeem owner PIN reset code, update PIN hash to bcrypt, unlock account, and revoke all sessions."""
    now = datetime.now(UTC)
    norm_phone = normalize_ph_phone_number(phone_number)

    res = await db.execute(
        select(BorrowerAccount).where(
            BorrowerAccount.phone_number_normalized == norm_phone
        )
    )
    account = res.scalar_one_or_none()
    if account is None:
        raise ValueError("Invalid phone number or reset code")

    code_hash = hash_secret(reset_code)
    stmt = (
        select(BorrowerPinReset)
        .where(
            BorrowerPinReset.borrower_account_id == account.id,
            BorrowerPinReset.used_at.is_(None),
        )
        .order_by(BorrowerPinReset.created_at.desc())
    )
    res_code = await db.execute(stmt)
    reset_rec = res_code.scalar_one_or_none()

    if reset_rec is None or reset_rec.expires_at < now:
        raise ValueError("Invalid or expired PIN reset code")

    if reset_rec.attempts >= reset_rec.max_attempts:
        raise ValueError("Maximum reset attempts exceeded. Request a new reset code from owner.")

    if reset_rec.code_hash != code_hash:
        reset_rec.attempts += 1
        await db.flush()
        remaining = reset_rec.max_attempts - reset_rec.attempts
        raise ValueError(f"Incorrect reset code. {remaining} attempt(s) remaining.")

    # Mark reset code as used
    reset_rec.used_at = now

    # Update PIN to bcrypt, unlock account
    account.password_hash = hash_pin_secure(new_pin)
    account.failed_login_attempts = 0
    account.locked_until = None
    account.updated_at = now

    # Revoke ALL active refresh tokens for account (force re-login on all devices)
    await db.execute(
        update(BorrowerRefreshToken)
        .where(
            BorrowerRefreshToken.borrower_account_id == account.id,
            BorrowerRefreshToken.revoked_at.is_(None),
        )
        .values(revoked_at=now)
    )

    audit = BorrowerRegistrationAudit(
        id=secrets.token_hex(18),
        actor_user_id=None,
        action="pin_reset_completed",
        target_type="borrower_account",
        target_id=account.id,
        created_at=now,
    )
    db.add(audit)
    await db.flush()
    return True


async def unlock_borrower_account(
    db: AsyncSession,
    account_id: str,
    owner_user: User,
) -> BorrowerAccount:
    """Owner endpoint to immediately unlock a locked borrower account."""
    now = datetime.now(UTC)
    account = await db.get(BorrowerAccount, account_id)
    if account is None:
        raise ValueError("Borrower account not found")

    account.failed_login_attempts = 0
    account.locked_until = None
    account.updated_at = now

    audit = BorrowerRegistrationAudit(
        id=secrets.token_hex(18),
        actor_user_id=owner_user.id,
        action="account_unlocked",
        target_type="borrower_account",
        target_id=account.id,
        created_at=now,
    )
    db.add(audit)
    await db.flush()
    return account


async def force_logout_borrower(
    db: AsyncSession,
    account_id: str,
    owner_user: User,
) -> int:
    """Owner endpoint to force logout all sessions for a borrower account."""
    now = datetime.now(UTC)
    account = await db.get(BorrowerAccount, account_id)
    if account is None:
        raise ValueError("Borrower account not found")

    cursor_result: CursorResult = await db.execute(  # type: ignore[assignment]
        update(BorrowerRefreshToken)
        .where(
            BorrowerRefreshToken.borrower_account_id == account.id,
            BorrowerRefreshToken.revoked_at.is_(None),
        )
        .values(revoked_at=now)
    )
    revoked_count = cursor_result.rowcount

    audit = BorrowerRegistrationAudit(
        id=secrets.token_hex(18),
        actor_user_id=owner_user.id,
        action="forced_logout_all",
        target_type="borrower_account",
        target_id=account.id,
        metadata_json=f'{{"revoked_sessions":{revoked_count}}}',
        created_at=now,
    )
    db.add(audit)
    await db.flush()
    return revoked_count


async def list_borrower_devices(
    db: AsyncSession,
    account_id: str,
) -> list[BorrowerDevice]:
    """Fetch active and registered devices for a borrower account."""
    stmt = (
        select(BorrowerDevice)
        .where(BorrowerDevice.borrower_account_id == account_id)
        .order_by(BorrowerDevice.last_seen_at.desc())
    )
    res = await db.execute(stmt)
    return list(res.scalars())


async def revoke_borrower_device(
    db: AsyncSession,
    account_id: str,
    device_id: str,
) -> bool:
    """Revoke a registered device and its active refresh tokens."""
    now = datetime.now(UTC)
    dev_stmt = select(BorrowerDevice).where(
        BorrowerDevice.id == device_id,
        BorrowerDevice.borrower_account_id == account_id,
    )
    res = await db.execute(dev_stmt)
    device = res.scalar_one_or_none()
    if device is None:
        raise ValueError("Device not found")

    device.is_active = False
    device.revoked_at = now
    device.updated_at = now

    # Revoke tokens associated with device
    await db.execute(
        update(BorrowerRefreshToken)
        .where(
            BorrowerRefreshToken.borrower_account_id == account_id,
            BorrowerRefreshToken.device_id == device.id,
            BorrowerRefreshToken.revoked_at.is_(None),
        )
        .values(revoked_at=now)
    )
    await db.flush()
    return True


async def owner_trust_borrower_device(
    db: AsyncSession,
    device_id: str,
    owner_user: User,
) -> BorrowerDevice:
    """Owner endpoint to mark a borrower device as trusted."""
    now = datetime.now(UTC)
    device = await db.get(BorrowerDevice, device_id)
    if device is None:
        raise ValueError("Device not found")

    device.is_trusted = True
    device.is_active = True
    device.revoked_at = None
    device.updated_at = now

    audit = BorrowerRegistrationAudit(
        id=secrets.token_hex(18),
        actor_user_id=owner_user.id,
        action="device_trusted",
        target_type="borrower_device",
        target_id=device.id,
        created_at=now,
    )
    db.add(audit)
    await db.flush()
    return device



