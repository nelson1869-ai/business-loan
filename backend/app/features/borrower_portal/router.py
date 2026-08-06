"""Borrower portal API endpoints (/api/v1/client) and officer invitation endpoint."""

import secrets
from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.database import get_db
from app.core.dependencies import CurrentUser
from app.core.phone_numbers import normalize_ph_phone_number
from app.core.rate_limiter import opaque_rate_limit_key
from app.features.borrower_portal.dashboard_schemas import BorrowerDashboardResponse
from app.features.borrower_portal.dashboard_service import get_borrower_dashboard
from app.features.borrower_portal.dependencies import ActiveBorrowerAccount
from app.features.borrower_portal.loans_schemas import (
    BorrowerInstallmentScheduleResponse,
    BorrowerLoanDetailResponse,
    BorrowerLoanListResponse,
)
from app.features.borrower_portal.loans_service import (
    get_borrower_loan_detail,
    get_borrower_loan_schedule,
    get_borrower_loans,
)
from app.features.borrower_portal.models import BorrowerDevice
from app.features.borrower_portal.payments_schemas import (
    BorrowerPaymentHistoryResponse,
    BorrowerReceiptDetailResponse,
)
from app.features.borrower_portal.payments_service import (
    get_borrower_loan_payments,
    get_borrower_payment_receipt,
)
from app.features.borrower_portal.schemas import (
    BorrowerActivationRequest,
    BorrowerLoanRequestResponse,
    BorrowerLoanRequestSubmit,
    BorrowerPINLoginRequest,
    BorrowerProfileResponse,
    BorrowerRegistrationItemResponse,
    BorrowerRegistrationSubmitRequest,
    BorrowerTokenResponse,
    ClientInvitationRequest,
    ClientInvitationResponse,
    DeviceRegisterRequest,
    DeviceResponse,
    OTPRequest,
    OTPRequestResponse,
    OTPVerifyRequest,
    OwnerApproveRegistrationResponse,
    RefreshTokenRequest,
    ReviewBorrowerLoanRequestPayload,
)
from app.features.borrower_portal.service import (
    approve_borrower_registration,
    generate_new_activation_code,
    get_borrower_profile,
    hash_secret,
    issue_client_invitation,
    list_borrower_loan_requests,
    login_borrower_with_pin,
    request_otp,
    review_borrower_loan_request,
    revoke_borrower_refresh_token,
    rotate_borrower_refresh_token,
    submit_borrower_loan_request,
    submit_borrower_registration,
    verify_activation_code_and_activate,
    verify_otp_and_login,
)
from app.features.borrowers import service as borrower_service

client_router = APIRouter(prefix="/api/v1/client", tags=["Borrower Client API"])
officer_router = APIRouter(prefix="/api/v1/borrowers", tags=["Borrower Invitations"])

DbSession = Annotated[AsyncSession, Depends(get_db)]


@client_router.post("/auth/request-otp", response_model=OTPRequestResponse)
async def request_borrower_otp(
    payload: OTPRequest,
    request: Request,
    db: DbSession,
) -> OTPRequestResponse:
    """Public endpoint to request an SMS OTP code without account enumeration."""
    settings = get_settings()
    try:
        identity = normalize_ph_phone_number(payload.phone_number)
    except ValueError:
        identity = "invalid"
    client_ip = request.client.host if request.client else "unknown"
    limiter_key = opaque_rate_limit_key(
        "borrower-request-otp", client_ip, identity, secret=settings.jwt_secret_key
    )
    if not await request.app.state.rate_limiter.allow(
        limiter_key, settings.login_rate_limit_per_minute
    ):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests. Please try again later.",
        )
    _, cooldown = await request_otp(db, payload.phone_number, payload.invitation_code)
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
        (
            account,
            access_token,
            new_refresh_token,
            expires_in,
        ) = await rotate_borrower_refresh_token(db, payload.refresh_token)
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
@client_router.get("/profile", response_model=BorrowerProfileResponse)
async def get_borrower_profile_endpoint(
    db: DbSession,
    current_account: ActiveBorrowerAccount,
) -> BorrowerProfileResponse:
    """Return profile details for the authenticated borrower identity."""
    return await get_borrower_profile(db, current_account)


@client_router.get("/dashboard", response_model=BorrowerDashboardResponse)
async def get_client_dashboard(
    db: DbSession,
    current_account: ActiveBorrowerAccount,
) -> BorrowerDashboardResponse:
    """Return read-only dashboard overview for the authenticated borrower."""
    return await get_borrower_dashboard(db, current_account)


@client_router.get("/loans", response_model=BorrowerLoanListResponse)
async def list_borrower_loans(
    db: DbSession,
    current_account: ActiveBorrowerAccount,
    status: str | None = Query(
        default=None,
        description="Filter loans by status (active, paid, overdue, etc.)",
    ),
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=20, ge=1, le=100),
) -> BorrowerLoanListResponse:
    """Return paginated, borrower-scoped loan list for the authenticated borrower."""
    return await get_borrower_loans(
        db,
        current_account,
        status_filter=status,
        offset=offset,
        limit=limit,
    )


@client_router.get("/loans/{loan_id}", response_model=BorrowerLoanDetailResponse)
async def get_borrower_loan(
    loan_id: str,
    db: DbSession,
    current_account: ActiveBorrowerAccount,
) -> BorrowerLoanDetailResponse:
    """Return read-only loan detail overview for the authenticated borrower."""
    detail = await get_borrower_loan_detail(db, current_account, loan_id)
    if detail is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Loan not found",
        )
    return detail


@client_router.get(
    "/loans/{loan_id}/schedule",
    response_model=BorrowerInstallmentScheduleResponse,
)
async def get_borrower_loan_schedule_endpoint(
    loan_id: str,
    db: DbSession,
    current_account: ActiveBorrowerAccount,
) -> BorrowerInstallmentScheduleResponse:
    """Return complete ledger-backed installment schedule for the authenticated borrower."""
    return await get_borrower_loan_schedule(db, current_account, loan_id)


@client_router.get(
    "/loans/{loan_id}/payments",
    response_model=BorrowerPaymentHistoryResponse,
)
async def get_borrower_loan_payments_endpoint(
    loan_id: str,
    db: DbSession,
    current_account: ActiveBorrowerAccount,
) -> BorrowerPaymentHistoryResponse:
    """Return borrower-scoped payment history for a specific loan."""
    return await get_borrower_loan_payments(db, current_account, loan_id)


@client_router.get(
    "/payments/{payment_id}/receipt",
    response_model=BorrowerReceiptDetailResponse,
)
async def get_borrower_payment_receipt_endpoint(
    payment_id: str,
    db: DbSession,
    current_account: ActiveBorrowerAccount,
) -> BorrowerReceiptDetailResponse:
    """Return digital receipt overview with allocation breakdown for a borrower payment."""
    return await get_borrower_payment_receipt(db, current_account, payment_id)


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


# ── Single-Owner Registration, Activation & Loan Request Routes ───────────────


@client_router.post(
    "/auth/register",
    response_model=BorrowerRegistrationItemResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register_borrower_client(
    payload: BorrowerRegistrationSubmitRequest,
    db: DbSession,
) -> BorrowerRegistrationItemResponse:
    """Public sign-up endpoint for borrowers (Status = Pending)."""
    try:
        req = await submit_borrower_registration(db, payload)
        await db.commit()
    except ValueError as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error

    return BorrowerRegistrationItemResponse(
        id=req.id,
        first_name=req.first_name,
        last_name=req.last_name,
        phone_number=req.phone_number,
        address=req.address,
        date_of_birth=req.date_of_birth.isoformat(),
        national_id=req.national_id,
        id_photo_url=req.id_photo_url,
        selfie_url=req.selfie_url,
        status=req.status,
        rejection_reason=req.rejection_reason,
        submitted_at=req.submitted_at,
    )


@client_router.post("/auth/activate", response_model=BorrowerTokenResponse)
async def activate_borrower_client(
    payload: BorrowerActivationRequest,
    request: Request,
    db: DbSession,
) -> BorrowerTokenResponse:
    """Redeem 6-digit owner activation code and obtain tokens."""
    client_ip = request.client.host if request.client else None
    try:
        account, access_token, refresh_token, expires_in = (
            await verify_activation_code_and_activate(db, payload, client_ip)
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


@client_router.post("/auth/login", response_model=BorrowerTokenResponse)
async def login_borrower_pin(
    payload: BorrowerPINLoginRequest,
    db: DbSession,
) -> BorrowerTokenResponse:
    """PIN / Password login endpoint for activated borrowers."""
    try:
        account, access_token, refresh_token, expires_in = (
            await login_borrower_with_pin(db, payload)
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
        refresh_token=refresh_token,
        token_type="Bearer",
        expires_in=expires_in,
        borrower_account_id=account.id,
        borrower_id=account.borrower_id,
        account_status=account.account_status,
    )


@client_router.post(
    "/loan-requests",
    response_model=BorrowerLoanRequestResponse,
    status_code=status.HTTP_201_CREATED,
)
async def submit_loan_request_endpoint(
    payload: BorrowerLoanRequestSubmit,
    db: DbSession,
    current_account: ActiveBorrowerAccount,
) -> BorrowerLoanRequestResponse:
    """Borrower endpoint to submit a new loan request."""
    req = await submit_borrower_loan_request(db, current_account, payload)
    await db.commit()
    return BorrowerLoanRequestResponse(
        id=req.id,
        borrower_id=req.borrower_id,
        requested_amount=str(req.requested_amount),
        requested_term_months=req.requested_term_months,
        purpose=req.purpose,
        status=req.status,
        owner_notes=req.owner_notes,
        created_draft_loan_id=req.created_draft_loan_id,
        created_at=req.created_at,
    )


@client_router.get(
    "/loan-requests",
    response_model=list[BorrowerLoanRequestResponse],
)
async def list_client_loan_requests(
    db: DbSession,
    current_account: ActiveBorrowerAccount,
) -> list[BorrowerLoanRequestResponse]:
    """Fetch loan request history for current borrower."""
    requests = await list_borrower_loan_requests(db, current_account)
    return [
        BorrowerLoanRequestResponse(
            id=r.id,
            borrower_id=r.borrower_id,
            requested_amount=str(r.requested_amount),
            requested_term_months=r.requested_term_months,
            purpose=r.purpose,
            status=r.status,
            owner_notes=r.owner_notes,
            created_draft_loan_id=r.created_draft_loan_id,
            created_at=r.created_at,
        )
        for r in requests
    ]

