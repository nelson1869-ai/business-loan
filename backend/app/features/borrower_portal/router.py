"""Borrower portal API endpoints (/api/v1/client) and officer invitation endpoint."""

import secrets
from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import CurrentUser
from app.features.borrower_portal.dependencies import ActiveBorrowerAccount
from app.features.borrower_portal.models import BorrowerDevice
from app.features.borrower_portal.schemas import (
    BorrowerProfileResponse,
    BorrowerTokenResponse,
    ClientInvitationRequest,
    ClientInvitationResponse,
    DeviceRegisterRequest,
    DeviceResponse,
    OTPRequest,
    OTPRequestResponse,
    OTPVerifyRequest,
    RefreshTokenRequest,
)
from app.features.borrower_portal.service import (
    hash_secret,
    issue_client_invitation,
    request_otp,
    revoke_borrower_refresh_token,
    rotate_borrower_refresh_token,
    verify_otp_and_login,
)
from app.features.borrowers import service as borrower_service

client_router = APIRouter(prefix="/api/v1/client", tags=["Borrower Client API"])
officer_router = APIRouter(prefix="/api/v1/borrowers", tags=["Borrower Invitations"])

DbSession = Annotated[AsyncSession, Depends(get_db)]


@client_router.post("/auth/request-otp", response_model=OTPRequestResponse)
async def request_borrower_otp(
    payload: OTPRequest,
    db: DbSession,
) -> OTPRequestResponse:
    """Public endpoint to request an SMS OTP code without account enumeration."""
    _, cooldown = await request_otp(
        db, payload.phone_number, payload.invitation_code
    )
    await db.commit()
    return OTPRequestResponse(
        message="If the phone number is eligible, an OTP has been sent.",
        resend_cooldown_seconds=cooldown,
    )


@client_router.post("/auth/verify-otp", response_model=BorrowerTokenResponse)
async def verify_borrower_otp(
    payload: OTPVerifyRequest,
    db: DbSession,
) -> BorrowerTokenResponse:
    """Verify OTP code, link/activate account, and return borrower access/refresh tokens."""
    try:
        account, access_token, refresh_token, expires_in = await verify_otp_and_login(
            db,
            payload.phone_number,
            payload.otp,
            payload.invitation_code,
            payload.device_identifier,
            payload.platform,
            payload.push_token,
        )
        await db.commit()
    except ValueError as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error

    return BorrowerTokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="Bearer",
        expires_in=expires_in,
        borrower_account_id=account.id,
        borrower_id=account.borrower_id,
        account_status=account.account_status,
    )


@client_router.post("/auth/refresh", response_model=BorrowerTokenResponse)
async def refresh_borrower_token(
    payload: RefreshTokenRequest,
    db: DbSession,
) -> BorrowerTokenResponse:
    """Rotate borrower refresh token and issue a fresh access token."""
    try:
        account, access_token, new_refresh_token, expires_in = (
            await rotate_borrower_refresh_token(db, payload.refresh_token)
        )
        await db.commit()
    except ValueError as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(error),
        ) from error

    return BorrowerTokenResponse(
        access_token=access_token,
        refresh_token=new_refresh_token,
        token_type="Bearer",
        expires_in=expires_in,
        borrower_account_id=account.id,
        borrower_id=account.borrower_id,
        account_status=account.account_status,
    )


@client_router.post("/auth/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout_borrower(
    payload: RefreshTokenRequest | None,
    db: DbSession,
    current_account: ActiveBorrowerAccount,
) -> None:
    """Revoke borrower refresh token on logout."""
    del current_account
    if payload and payload.refresh_token:
        await revoke_borrower_refresh_token(db, payload.refresh_token)
        await db.commit()


@client_router.get("/me", response_model=BorrowerProfileResponse)
async def get_borrower_profile(
    db: DbSession,
    current_account: ActiveBorrowerAccount,
) -> BorrowerProfileResponse:
    """Return profile details for the authenticated borrower identity."""
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
        phone_number=current_account.phone_number_normalized,
        account_status=current_account.account_status,
        created_at=current_account.created_at,
    )


@client_router.post("/devices", response_model=DeviceResponse)
async def register_borrower_device(
    payload: DeviceRegisterRequest,
    db: DbSession,
    current_account: ActiveBorrowerAccount,
) -> DeviceResponse:
    """Register or update device push tokens for active borrower account."""
    now = datetime.now(UTC)
    device_hash = hash_secret(payload.device_identifier)
    stmt = select(BorrowerDevice).where(
        BorrowerDevice.borrower_account_id == current_account.id,
        BorrowerDevice.device_identifier_hash == device_hash,
    )
    res = await db.execute(stmt)
    device = res.scalar_one_or_none()
    if device is None:
        device = BorrowerDevice(
            id=secrets.token_hex(18),
            borrower_account_id=current_account.id,
            device_identifier_hash=device_hash,
            platform=payload.platform,
            push_token=payload.push_token,
            last_seen_at=now,
            is_active=True,
            created_at=now,
            updated_at=now,
        )
        db.add(device)
    else:
        device.is_active = True
        device.platform = payload.platform
        device.last_seen_at = now
        device.updated_at = now
        if payload.push_token is not None:
            device.push_token = payload.push_token
            device.push_token_updated_at = now

    await db.commit()
    await db.refresh(device)
    return DeviceResponse(
        id=device.id,
        platform=device.platform,
        is_active=device.is_active,
        last_seen_at=device.last_seen_at,
    )


@client_router.delete("/devices/{device_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_borrower_device(
    device_id: str,
    db: DbSession,
    current_account: ActiveBorrowerAccount,
) -> None:
    """Deactivate a registered device associated with current borrower."""
    stmt = select(BorrowerDevice).where(
        BorrowerDevice.id == device_id,
        BorrowerDevice.borrower_account_id == current_account.id,
    )
    res = await db.execute(stmt)
    device = res.scalar_one_or_none()
    if device is not None:
        device.is_active = False
        device.updated_at = datetime.now(UTC)
        await db.commit()


@officer_router.post(
    "/{borrower_id}/client-invitation",
    response_model=ClientInvitationResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_client_invitation(
    borrower_id: str,
    payload: ClientInvitationRequest,
    db: DbSession,
    current_user: CurrentUser,
) -> ClientInvitationResponse:
    """Officer endpoint to issue a 6-digit client activation code for a borrower."""
    if current_user.role not in ("officer", "manager", "admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to issue client invitations",
        )

    borrower = await borrower_service.get_borrower(db, borrower_id)
    if borrower is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Borrower not found",
        )

    invitation, raw_code = await issue_client_invitation(
        db, borrower_id, current_user, payload.expires_in_hours
    )
    await db.commit()

    return ClientInvitationResponse(
        id=invitation.id,
        borrower_id=invitation.borrower_id,
        invitation_code=raw_code,
        expires_at=invitation.expires_at,
        created_at=invitation.created_at,
    )
