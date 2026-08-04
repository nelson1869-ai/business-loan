"""Borrower portal business logic and security service."""

import asyncio
import hashlib
import hmac
import secrets
from datetime import UTC, datetime, timedelta
from typing import Any

import jwt
from fastapi import HTTPException, status
from jwt.exceptions import PyJWTError
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.phone_numbers import normalize_ph_phone_number
from app.features.auth.service import TokenValidationError
from app.features.borrower_portal.models import (
    BorrowerAccount,
    BorrowerDevice,
    BorrowerInvitation,
    BorrowerOTP,
    BorrowerRefreshToken,
)
from app.features.borrower_portal.otp_provider import (
    DevelopmentOTPProvider,
    dev_otp_provider,
    get_otp_provider,
)
from app.features.borrower_portal.schemas import BorrowerProfileResponse
from app.features.borrowers import service as borrower_service
from app.features.borrowers.models import Borrower
from app.features.users.models import User

LOCAL_DEVELOPMENT_OTP = "123456"


def hash_secret(secret_text: str) -> str:
    """Return a deterministic SHA-256 hex hash of an OTP or token string."""
    return hashlib.sha256(secret_text.encode("utf-8")).hexdigest()


def generate_otp_code() -> str:
    """Generate a cryptographically secure 6-digit OTP string."""
    return f"{secrets.randbelow(1000000):06d}"


def generate_invitation_code() -> str:
    """Generate an officer-issued 6-digit invitation code."""
    return f"{secrets.randbelow(1000000):06d}"


async def issue_client_invitation(
    db: AsyncSession,
    borrower_id: str,
    officer: User,
    expires_in_hours: int = 72,
) -> tuple[BorrowerInvitation, str]:
    """Issue a 6-digit invitation code for borrower account linking."""
    raw_code = generate_invitation_code()
    code_hash = hash_secret(raw_code)
    now = datetime.now(UTC)
    invitation = BorrowerInvitation(
        id=secrets.token_hex(18),
        borrower_id=borrower_id,
        invitation_code_hash=code_hash,
        expires_at=now + timedelta(hours=expires_in_hours),
        created_by_user_id=officer.id,
        created_at=now,
    )
    db.add(invitation)
    await db.flush()
    return invitation, raw_code


async def request_otp(
    db: AsyncSession,
    raw_phone: str,
    invitation_code: str | None = None,
    settings: Settings | None = None,
) -> tuple[bool, int]:
    """Request an OTP for an eligible phone number without leaking account existence."""
    current_settings = settings or get_settings()
    try:
        normalized_phone = normalize_ph_phone_number(raw_phone)
    except ValueError:
        # Generic response preserves privacy on malformed phone
        return False, 60

    now = datetime.now(UTC)

    # Only an approved/active account or a valid invitation is OTP-eligible.
    # The public response remains identical for all other identities.
    account_result = await db.execute(
        select(BorrowerAccount).where(
            BorrowerAccount.phone_number_normalized == normalized_phone,
            BorrowerAccount.account_status.in_(("approved", "active")),
        )
    )
    account = account_result.scalar_one_or_none()
    invitation_is_valid = False
    if invitation_code:
        invitation_result = await db.execute(
            select(BorrowerInvitation).where(
                BorrowerInvitation.invitation_code_hash == hash_secret(invitation_code),
                BorrowerInvitation.used_at.is_(None),
                BorrowerInvitation.expires_at > now,
            )
        )
        invitation_is_valid = invitation_result.scalar_one_or_none() is not None
    if account is None and not invitation_is_valid:
        return False, 60

    # Check resend cooldown
    stmt = (
        select(BorrowerOTP)
        .where(BorrowerOTP.phone_number_normalized == normalized_phone)
        .order_by(BorrowerOTP.created_at.desc())
        .limit(1)
    )
    res = await db.execute(stmt)
    latest_otp = res.scalar_one_or_none()

    if latest_otp is not None and latest_otp.resend_available_at > now:
        cooldown = int((latest_otp.resend_available_at - now).total_seconds())
        return True, max(cooldown, 1)

    # Generate and store OTP
    otp_code = (
        LOCAL_DEVELOPMENT_OTP
        if current_settings.local_borrower_otp_enabled
        else generate_otp_code()
    )
    otp_hash = hash_secret(otp_code)
    new_otp = BorrowerOTP(
        id=secrets.token_hex(18),
        phone_number_normalized=normalized_phone,
        otp_code_hash=otp_hash,
        expires_at=now + timedelta(minutes=5),
        resend_available_at=now + timedelta(seconds=60),
        attempts=0,
        created_at=now,
    )
    db.add(new_otp)
    await db.flush()

    # Dispatch via configured OTP provider (dev or Android SMS gateway)
    otp_provider = get_otp_provider(current_settings)
    await otp_provider.send_otp(normalized_phone, otp_code)
    return True, 60


async def verify_otp_and_login(
    db: AsyncSession,
    raw_phone: str,
    otp: str,
    invitation_code: str | None,
    device_identifier: str,
    platform: str,
    push_token: str | None = None,
    settings: Settings | None = None,
) -> tuple[BorrowerAccount, str, str, int]:
    """Verify OTP code, perform safe account linking/activation, and issue JWT tokens."""
    current_settings = settings or get_settings()
    normalized_phone = normalize_ph_phone_number(raw_phone)
    now = datetime.now(UTC)

    # Fetch active non-expired OTP
    stmt = (
        select(BorrowerOTP)
        .where(
            BorrowerOTP.phone_number_normalized == normalized_phone,
            BorrowerOTP.used_at.is_(None),
            BorrowerOTP.expires_at > now,
        )
        .order_by(BorrowerOTP.created_at.desc())
        .limit(1)
    )
    res = await db.execute(stmt)
    otp_record = res.scalar_one_or_none()

    if otp_record is None:
        raise ValueError("Invalid or expired OTP")

    current_attempts = otp_record.attempts or 0

    if current_attempts >= 5:
        otp_record.used_at = now  # invalidate after max attempts
        await db.flush()
        raise ValueError("Maximum OTP verification attempts exceeded")

    otp_record.attempts = current_attempts + 1
    input_hash = hash_secret(otp)
    if not hmac.compare_digest(otp_record.otp_code_hash, input_hash):
        await db.flush()
        raise ValueError("Invalid or expired OTP")

    # Mark OTP as used
    otp_record.used_at = now

    # Fetch existing borrower account
    acct_stmt = select(BorrowerAccount).where(
        BorrowerAccount.phone_number_normalized == normalized_phone
    )
    acct_res = await db.execute(acct_stmt)
    account = acct_res.scalar_one_or_none()

    if account is None:
        # Require invitation code for initial linking if no account exists yet
        if not invitation_code:
            raise ValueError("Activation code required for initial account setup")

        inv_hash = hash_secret(invitation_code)
        inv_stmt = (
            select(BorrowerInvitation)
            .where(
                BorrowerInvitation.invitation_code_hash == inv_hash,
                BorrowerInvitation.used_at.is_(None),
                BorrowerInvitation.expires_at > now,
            )
            .limit(1)
        )
        inv_res = await db.execute(inv_stmt)
        invitation = inv_res.scalar_one_or_none()
        if invitation is None:
            raise ValueError("Invalid or expired activation code")

        # Verify matching borrower
        borrower = await db.get(Borrower, invitation.borrower_id)
        if borrower is None or borrower.status != "Active":
            raise ValueError("Associated borrower is not eligible for portal access")

        account = BorrowerAccount(
            id=secrets.token_hex(18),
            borrower_id=borrower.id,
            phone_number=raw_phone,
            phone_number_normalized=normalized_phone,
            phone_verified_at=now,
            account_status="active",
            created_at=now,
            updated_at=now,
        )
        db.add(account)
        invitation.used_at = now
        await db.flush()
    else:
        if account.account_status in ("suspended", "disabled"):
            raise ValueError("Borrower account is disabled or suspended")
        if account.phone_verified_at is None:
            account.phone_verified_at = now
        account.account_status = "active"
        account.last_login_at = now
        await db.flush()

    # Register/update device
    device_hash = hash_secret(device_identifier)
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
            platform=platform,
            push_token=push_token,
            last_seen_at=now,
            is_active=True,
            created_at=now,
            updated_at=now,
        )
        db.add(device)
    else:
        device.last_seen_at = now
        device.is_active = True
        if push_token is not None:
            device.push_token = push_token
            device.push_token_updated_at = now
    await db.flush()

    # Create JWT Tokens
    access_token = create_borrower_access_token(account, current_settings)
    raw_refresh_token = secrets.token_urlsafe(32)
    refresh_hash = hash_secret(raw_refresh_token)

    refresh_record = BorrowerRefreshToken(
        id=secrets.token_hex(18),
        borrower_account_id=account.id,
        token_hash=refresh_hash,
        device_id=device.id,
        expires_at=now + timedelta(days=current_settings.refresh_token_expire_days),
        created_at=now,
    )
    db.add(refresh_record)
    await db.flush()

    expires_in_sec = current_settings.access_token_expire_minutes * 60
    return account, access_token, raw_refresh_token, expires_in_sec


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
