"""Public self-registration and authorized staff review endpoints."""

from typing import Annotated, Any, cast

from fastapi import APIRouter, HTTPException, Query, Request
from sqlalchemy.exc import IntegrityError

from app.core.authorization import require_owner
from app.core.config import get_settings
from app.core.dependencies import CurrentUser, DbSession
from app.core.masking import mask_national_id, mask_phone
from app.core.rate_limiter import opaque_rate_limit_key
from app.features.borrower_portal import registration_service as service
from app.features.borrower_portal.models import BorrowerRegistrationRequest
from app.features.borrower_portal.registration_schemas import (
    AccountAction,
    AccountActionResponse,
    AccountRelink,
    RegistrationApproval,
    RegistrationCreate,
    RegistrationCreateAndApproval,
    RegistrationListItem,
    RegistrationRejection,
    RegistrationStatusRequest,
    RegistrationStatusResponse,
    RegistrationSubmitted,
)

public_router = APIRouter(prefix="/api/v1/client/auth", tags=["Borrower Registration"])
staff_router = APIRouter(prefix="/api/v1", tags=["Borrower Registration Management"])


async def _rate_limit(request: Request, namespace: str, identity: str) -> None:
    settings = get_settings()
    client_ip = request.client.host if request.client else "unknown"
    key = opaque_rate_limit_key(
        namespace, client_ip, identity, secret=settings.jwt_secret_key
    )
    if not await request.app.state.rate_limiter.allow(
        key, settings.login_rate_limit_per_minute
    ):
        raise HTTPException(
            status_code=429,
            detail="Too many registration requests. Please wait a minute and try again.",
        )


@public_router.post("/register", response_model=RegistrationSubmitted, status_code=201)
async def register_borrower(
    payload: RegistrationCreate, request: Request, db: DbSession
) -> RegistrationSubmitted:
    await _rate_limit(request, "borrower-registration", payload.phone_number)
    try:
        item, token = await service.submit(db, payload)
        await db.commit()
    except service.RegistrationConflict as error:
        await db.rollback()
        raise HTTPException(status_code=409, detail=str(error)) from error
    except IntegrityError as error:
        await db.rollback()
        raise HTTPException(
            status_code=409,
            detail="A registration request with this phone number or identity already exists.",
        ) from error
    return RegistrationSubmitted(request_id=item.id, registration_token=token)


@public_router.post("/registration-status", response_model=RegistrationStatusResponse)
async def registration_status(
    payload: RegistrationStatusRequest, request: Request, db: DbSession
) -> RegistrationStatusResponse:
    await _rate_limit(
        request, "borrower-registration-status", payload.registration_token
    )
    current_status, message = await service.status_for_token(
        db, payload.registration_token
    )
    return RegistrationStatusResponse(status=cast(Any, current_status), message=message)


async def _build_item(
    db: DbSession, row: BorrowerRegistrationRequest
) -> RegistrationListItem:
    matches_raw = await service.find_possible_borrower_matches(db, row)
    return RegistrationListItem(
        id=row.id,
        first_name=row.first_name,
        middle_name=row.middle_name,
        last_name=row.last_name,
        suffix=row.suffix,
        masked_national_id=mask_national_id(row.national_id),
        has_national_id=row.national_id is not None,
        masked_phone=mask_phone(row.phone_number_normalized),
        date_of_birth=row.date_of_birth,
        email=row.email,
        status=row.status,
        submitted_at=row.submitted_at,
        linked_borrower_id=row.linked_borrower_id,
        possible_matches=matches_raw,
    )


@staff_router.get(
    "/borrower-registration-requests", response_model=list[RegistrationListItem]
)
async def list_registrations(
    db: DbSession,
    current_user: CurrentUser,
    requested_status: Annotated[
        str,
        Query(
            alias="status", pattern="^(pending|approved|rejected|cancelled|expired)$"
        ),
    ] = "pending",
    offset: Annotated[int, Query(ge=0)] = 0,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
) -> list[RegistrationListItem]:
    require_owner(current_user)
    rows = await service.list_requests(db, requested_status, offset, limit)
    return [await _build_item(db, row) for row in rows]


@staff_router.get(
    "/borrower-registration-requests/{request_id}", response_model=RegistrationListItem
)
async def registration_detail(
    request_id: str, db: DbSession, current_user: CurrentUser
) -> RegistrationListItem:
    require_owner(current_user)
    row = await db.get(BorrowerRegistrationRequest, request_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Registration request not found")
    return await _build_item(db, row)


@staff_router.post(
    "/borrower-registration-requests/{request_id}/approve",
    response_model=AccountActionResponse,
)
async def approve_registration(
    request_id: str,
    payload: RegistrationApproval,
    db: DbSession,
    current_user: CurrentUser,
) -> AccountActionResponse:
    require_owner(current_user)
    try:
        account = await service.approve(
            db, request_id, payload.borrower_id, current_user, payload.review_notes
        )
        if account is None:
            raise HTTPException(
                status_code=404, detail="Registration request not found"
            )
        await db.commit()
    except (service.RegistrationConflict, IntegrityError) as error:
        await db.rollback()
        raise HTTPException(status_code=409, detail=str(error)) from error
    return AccountActionResponse(
        account_id=account.id,
        account_status=account.account_status,
        borrower_id=account.borrower_id,
    )


@staff_router.post(
    "/borrower-registration-requests/{request_id}/create-and-approve",
    response_model=AccountActionResponse,
    status_code=201,
)
async def create_and_approve_registration(
    request_id: str,
    payload: RegistrationCreateAndApproval,
    db: DbSession,
    current_user: CurrentUser,
) -> AccountActionResponse:
    require_owner(current_user)
    try:
        account = await service.create_and_approve(
            db,
            request_id,
            payload.national_id,
            current_user,
            payload.review_notes,
        )
        if account is None:
            raise HTTPException(
                status_code=404, detail="Registration request not found"
            )
        await db.commit()
    except (service.RegistrationConflict, IntegrityError) as error:
        await db.rollback()
        detail = (
            str(error)
            if isinstance(error, service.RegistrationConflict)
            else "Borrower identity is already registered"
        )
        raise HTTPException(status_code=409, detail=detail) from error
    return AccountActionResponse(
        account_id=account.id,
        account_status=account.account_status,
        borrower_id=account.borrower_id,
    )


@staff_router.post(
    "/borrower-registration-requests/{request_id}/reject", status_code=204
)
async def reject_registration(
    request_id: str,
    payload: RegistrationRejection,
    db: DbSession,
    current_user: CurrentUser,
) -> None:
    require_owner(current_user)
    try:
        item = await service.reject(db, request_id, payload.reason, current_user)
        if item is None:
            raise HTTPException(
                status_code=404, detail="Registration request not found"
            )
        await db.commit()
    except service.RegistrationConflict as error:
        await db.rollback()
        raise HTTPException(status_code=409, detail=str(error)) from error


async def _account_action(
    account_id: str,
    action: str,
    payload: AccountAction,
    db: DbSession,
    user: CurrentUser,
    borrower_id: str | None = None,
) -> AccountActionResponse:
    require_owner(user)
    try:
        account = await service.account_action(
            db, account_id, action, user, payload.reason, borrower_id
        )
        if account is None:
            raise HTTPException(status_code=404, detail="Borrower account not found")
        await db.commit()
    except (service.RegistrationConflict, IntegrityError) as error:
        await db.rollback()
        raise HTTPException(status_code=409, detail=str(error)) from error
    return AccountActionResponse(
        account_id=account.id,
        account_status=account.account_status,
        borrower_id=account.borrower_id,
    )


@staff_router.post(
    "/borrower-accounts/{account_id}/suspend", response_model=AccountActionResponse
)
async def suspend(
    account_id: str, payload: AccountAction, db: DbSession, current_user: CurrentUser
) -> AccountActionResponse:
    return await _account_action(account_id, "suspend", payload, db, current_user)


@staff_router.post(
    "/borrower-accounts/{account_id}/reactivate", response_model=AccountActionResponse
)
async def reactivate(
    account_id: str, payload: AccountAction, db: DbSession, current_user: CurrentUser
) -> AccountActionResponse:
    return await _account_action(account_id, "reactivate", payload, db, current_user)


@staff_router.post(
    "/borrower-accounts/{account_id}/disable", response_model=AccountActionResponse
)
async def disable(
    account_id: str, payload: AccountAction, db: DbSession, current_user: CurrentUser
) -> AccountActionResponse:
    return await _account_action(account_id, "disable", payload, db, current_user)


@staff_router.post(
    "/borrower-accounts/{account_id}/relink", response_model=AccountActionResponse
)
async def relink(
    account_id: str, payload: AccountRelink, db: DbSession, current_user: CurrentUser
) -> AccountActionResponse:
    return await _account_action(
        account_id, "relink", payload, db, current_user, payload.borrower_id
    )
