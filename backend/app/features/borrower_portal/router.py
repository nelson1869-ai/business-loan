"""Borrower portal API endpoints (/api/v1/client) and officer invitation endpoint."""

import secrets
from datetime import UTC, datetime
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.authorization import require_owner
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
    BorrowerAppAccessStatusResponse,
    BorrowerLoanRequestResponse,
    BorrowerLoanRequestSubmit,
    BorrowerPINLoginRequest,
    BorrowerProfileResponse,
    BorrowerRegistrationItemResponse,
    BorrowerRegistrationSubmitRequest,
    BorrowerTokenResponse,
    ConfirmPINRequest,
    DeviceRegisterRequest,
    DeviceResponse,
    EnableAppAccessResponse,
    ForgotPINRequest,
    IssueResetCodeResponse,
    OwnerApproveRegistrationResponse,
    RefreshTokenRequest,
    ResetPINRequest,
    ReviewBorrowerLoanRequestPayload,
)
from app.features.borrower_portal.service import (
    approve_borrower_registration,
    confirm_borrower_pin,
    enable_existing_borrower_app_access,
    force_logout_borrower,
    generate_new_activation_code,
    get_borrower_app_access_status,
    get_borrower_profile,
    hash_secret,
    issue_pin_reset_code,
    list_borrower_devices,
    list_borrower_loan_requests,
    login_borrower_with_pin,
    owner_trust_borrower_device,
    redeem_pin_reset_code,
    request_pin_reset,
    review_borrower_loan_request,
    revoke_borrower_device,
    revoke_borrower_refresh_token,
    rotate_borrower_refresh_token,
    submit_borrower_loan_request,
    submit_borrower_registration,
    unlock_borrower_account,
    verify_activation_code_and_activate,
)
from app.features.borrowers import service as borrower_service

client_router = APIRouter(prefix="/api/v1/client", tags=["Borrower Client API"])
owner_router = APIRouter(prefix="/api/v1/borrowers", tags=["Owner Administration"])

DbSession = Annotated[AsyncSession, Depends(get_db)]





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


# ── Single-Owner Activation & Loan Request Routes ───────────────────────────


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


@client_router.post("/auth/confirm-pin", status_code=status.HTTP_200_OK)
async def confirm_borrower_pin_endpoint(
    payload: ConfirmPINRequest,
    db: DbSession,
    current_account: ActiveBorrowerAccount,
) -> dict[str, str]:
    """Confirm borrower PIN post-activation."""
    try:
        await confirm_borrower_pin(db, current_account, payload.pin)
        await db.commit()
    except ValueError as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error
    return {"message": "PIN confirmed successfully"}


@client_router.post("/auth/forgot-pin", status_code=status.HTTP_200_OK)
async def forgot_borrower_pin_endpoint(
    payload: ForgotPINRequest,
    db: DbSession,
) -> dict[str, str]:
    """Public endpoint to request PIN reset without exposing account existence."""
    _, message = await request_pin_reset(db, payload.phone_number)
    await db.commit()
    return {"message": message}


@client_router.post("/auth/reset-pin", status_code=status.HTTP_200_OK)
async def reset_borrower_pin_endpoint(
    payload: ResetPINRequest,
    db: DbSession,
) -> dict[str, str]:
    """Public endpoint to redeem owner PIN reset code and set new PIN."""
    try:
        await redeem_pin_reset_code(
            db, payload.phone_number, payload.reset_code, payload.new_pin
        )
        await db.commit()
    except ValueError as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error
    return {"message": "PIN reset successful. Please log in with your new PIN."}


@client_router.get("/devices", response_model=list[DeviceResponse])
async def list_client_devices(
    db: DbSession,
    current_account: ActiveBorrowerAccount,
) -> list[DeviceResponse]:
    """Fetch active registered devices for the authenticated borrower."""
    devices = await list_borrower_devices(db, current_account.id)
    return [
        DeviceResponse(
            id=d.id,
            platform=d.platform,
            device_name=d.device_name,
            model=d.model,
            app_version=d.app_version,
            is_trusted=d.is_trusted,
            is_active=d.is_active,
            first_seen_at=d.first_seen_at,
            last_seen_at=d.last_seen_at,
            revoked_at=d.revoked_at,
        )
        for d in devices
    ]


@client_router.post("/devices/{device_id}/revoke", status_code=status.HTTP_200_OK)
async def revoke_client_device(
    device_id: str,
    db: DbSession,
    current_account: ActiveBorrowerAccount,
) -> dict[str, str]:
    """Revoke a registered device for the authenticated borrower."""
    try:
        await revoke_borrower_device(db, current_account.id, device_id)
        await db.commit()
    except ValueError as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error
@owner_router.post(
    "/{borrower_id}/enable-app-access",
    response_model=EnableAppAccessResponse,
    status_code=status.HTTP_201_CREATED,
)
async def enable_app_access_endpoint(
    borrower_id: str,
    db: DbSession,
    current_user: CurrentUser,
) -> EnableAppAccessResponse:
    """Owner endpoint to enable Borrower App access for an existing Borrower record."""
    require_owner(current_user)
    try:
        response = await enable_existing_borrower_app_access(db, borrower_id, current_user)
        await db.commit()
        return response
    except ValueError as error:
        await db.rollback()
        detail_msg = str(error)
        status_code = status.HTTP_404_NOT_FOUND if "not found" in detail_msg.lower() else status.HTTP_409_CONFLICT
        raise HTTPException(status_code=status_code, detail=detail_msg) from error


@owner_router.get(
    "/{borrower_id}/app-access",
    response_model=BorrowerAppAccessStatusResponse,
)
async def get_app_access_status_endpoint(
    borrower_id: str,
    db: DbSession,
    current_user: CurrentUser,
) -> BorrowerAppAccessStatusResponse:
    """Owner endpoint to query borrower app access status. NEVER returns raw activation code."""
    require_owner(current_user)
    try:
        return await get_borrower_app_access_status(db, borrower_id)
    except ValueError as error:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(error)) from error


@owner_router.post("/accounts/{account_id}/unlock", status_code=status.HTTP_200_OK)
async def unlock_account_endpoint(
    account_id: str,
    db: DbSession,
    current_user: CurrentUser,
) -> dict[str, str]:
    """Owner endpoint to immediately unlock a locked borrower account."""
    if current_user.role != "owner":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Owner privilege required")
    try:
        await unlock_borrower_account(db, account_id, current_user)
        await db.commit()
    except ValueError as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error
    return {"message": "Borrower account unlocked successfully"}


@owner_router.post(
    "/accounts/{account_id}/reset-code",
    response_model=IssueResetCodeResponse,
    status_code=status.HTTP_201_CREATED,
)
async def issue_reset_code_endpoint(
    account_id: str,
    db: DbSession,
    current_user: CurrentUser,
) -> IssueResetCodeResponse:
    """Owner endpoint to issue a 6-digit PIN reset code for a borrower account."""
    if current_user.role != "owner":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Owner privilege required")
    try:
        activation, raw_code = await generate_new_activation_code(
            db, account_id, current_user
        )
        await db.commit()
    except ValueError as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error
    return IssueResetCodeResponse(
        account_id=activation.borrower_account_id,
        reset_code=raw_code,
        expires_at=activation.expires_at,
    )


@owner_router.post("/accounts/{account_id}/logout-all", status_code=status.HTTP_200_OK)
async def force_logout_endpoint(
    account_id: str,
    db: DbSession,
    current_user: CurrentUser,
) -> dict[str, Any]:
    """Owner endpoint to force logout all active sessions for a borrower."""
    if current_user.role != "owner":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Owner privilege required")
    try:
        count = await force_logout_borrower(db, account_id, current_user)
        await db.commit()
    except ValueError as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error
    return {"message": f"Revoked {count} active sessions", "revokedCount": count}


@owner_router.post("/devices/{device_id}/trust", response_model=DeviceResponse)
async def owner_trust_device_endpoint(
    device_id: str,
    db: DbSession,
    current_user: CurrentUser,
) -> DeviceResponse:
    """Owner endpoint to trust a borrower device."""
    if current_user.role != "owner":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Owner privilege required")
    try:
        device = await owner_trust_borrower_device(db, device_id, current_user)
        await db.commit()
    except ValueError as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error
    return DeviceResponse(
        id=device.id,
        platform=device.platform,
        device_name=device.device_name,
        model=device.model,
        app_version=device.app_version,
        is_trusted=device.is_trusted,
        is_active=device.is_active,
        first_seen_at=device.first_seen_at,
        last_seen_at=device.last_seen_at,
        revoked_at=device.revoked_at,
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

