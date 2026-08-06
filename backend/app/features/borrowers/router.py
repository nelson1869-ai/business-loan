from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Header, HTTPException, Query, Response, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.core.dependencies import CurrentUser, DbSession
from app.features.borrower_portal.models import BorrowerRegistrationRequest
from app.features.borrower_portal.schemas import (
    BorrowerRegistrationItemResponse,
    ClientInvitationRequest,
    ClientInvitationResponse,
    OwnerApproveRegistrationResponse,
)
from app.features.borrower_portal.service import (
    approve_borrower_registration,
    issue_client_invitation,
)
from app.features.borrowers import service as borrower_service
from app.features.borrowers.schemas import (
    BorrowerCreate,
    BorrowerIdentityCheck,
    BorrowerIdentityCheckResponse,
    BorrowerResponse,
    BorrowerUpdate,
)

router = APIRouter(prefix="/api/v1/borrowers", tags=["Borrowers"])


@router.post("/identity-check", response_model=BorrowerIdentityCheckResponse)
async def check_identity(
    payload: BorrowerIdentityCheck,
    db: DbSession,
    current_user: CurrentUser,
) -> BorrowerIdentityCheckResponse:
    """Preflight a borrower identity for an authenticated officer."""
    del current_user
    outcome, message, borrower_id = await borrower_service.check_borrower_identity(
        db,
        payload.first_name,
        payload.last_name,
        payload.national_id,
        payload.phone,
        payload.date_of_birth,
    )
    return BorrowerIdentityCheckResponse(
        outcome=outcome,
        message=message,
        borrower_id=borrower_id,
    )


@router.get("", response_model=list[BorrowerResponse])
async def list_all_borrowers(
    db: DbSession,
    current_user: CurrentUser,
    response: Response,
    borrower_status: Annotated[str | None, Query(alias="status")] = None,
    offset: Annotated[int, Query(ge=0)] = 0,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
) -> list[BorrowerResponse]:
    """List a filtered, paginated borrower page."""
    del current_user
    borrowers, total = await borrower_service.list_borrowers(
        db, borrower_status, offset, limit
    )
    response.headers["X-Total-Count"] = str(total)
    return [BorrowerResponse.model_validate(item) for item in borrowers]


@router.post("", response_model=BorrowerResponse, status_code=status.HTTP_201_CREATED)
async def register_borrower(
    payload: BorrowerCreate,
    db: DbSession,
    current_user: CurrentUser,
    transaction_uuid: Annotated[str | None, Header(alias="X-Transaction-UUID")] = None,
) -> BorrowerResponse:
    """Register one borrower and write a redacted audit record."""
    del transaction_uuid
    try:
        borrower = await borrower_service.create_borrower(db, payload, current_user)
        await db.commit()
    except borrower_service.BorrowerIdentityConflictError as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(error),
        ) from error
    except IntegrityError as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Borrower ID, national ID, or phone number already exists",
        ) from error
    await db.refresh(borrower)
    return BorrowerResponse.model_validate(borrower)


# ── Single-Owner Registration Review Endpoints ─────────────────────────────────


@router.get(
    "/registrations",
    response_model=list[BorrowerRegistrationItemResponse],
)
async def list_borrower_registrations(
    db: DbSession,
    current_user: CurrentUser,
    registration_status: str | None = Query(None, alias="status"),
    search: str | None = Query(None),
) -> list[BorrowerRegistrationItemResponse]:
    """Owner endpoint to view pending or past borrower registration applications."""
    if current_user.role not in ("officer", "manager", "admin", "owner"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions",
        )
    stmt = select(BorrowerRegistrationRequest)
    if registration_status is not None:
        stmt = stmt.where(BorrowerRegistrationRequest.status == registration_status)
    if search is not None and search.strip():
        term = f"%{search.strip()}%"
        stmt = stmt.where(
            (BorrowerRegistrationRequest.first_name.ilike(term))
            | (BorrowerRegistrationRequest.last_name.ilike(term))
            | (BorrowerRegistrationRequest.phone_number.ilike(term))
        )
    stmt = stmt.order_by(BorrowerRegistrationRequest.submitted_at.desc())
    res = await db.execute(stmt)
    items = list(res.scalars())
    return [
        BorrowerRegistrationItemResponse(
            id=r.id,
            first_name=r.first_name,
            last_name=r.last_name,
            phone_number=r.phone_number,
            address=r.address,
            date_of_birth=r.date_of_birth.isoformat(),
            national_id=r.national_id,
            id_photo_url=r.id_photo_url,
            selfie_url=r.selfie_url,
            status=r.status,
            rejection_reason=r.rejection_reason,
            submitted_at=r.submitted_at,
        )
        for r in items
    ]


@router.post(
    "/registrations/{registration_id}/approve",
    response_model=OwnerApproveRegistrationResponse,
)
async def approve_borrower_registration_endpoint(
    registration_id: str,
    db: DbSession,
    current_user: CurrentUser,
) -> OwnerApproveRegistrationResponse:
    """Owner endpoint to approve a borrower registration and generate 6-digit Activation Code."""
    if current_user.role not in ("admin", "owner", "manager", "officer"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions to approve borrower registrations",
        )
    try:
        result = await approve_borrower_registration(db, registration_id, current_user)
        await db.commit()
        return result
    except ValueError as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        ) from error


@router.post("/registrations/{registration_id}/reject")
async def reject_borrower_registration_endpoint(
    registration_id: str,
    db: DbSession,
    current_user: CurrentUser,
    reason: str = Query("Registration rejected by owner"),
) -> dict[str, str]:
    """Owner endpoint to reject a pending borrower registration."""
    if current_user.role not in ("admin", "owner", "manager", "officer"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions",
        )
    res = await db.execute(
        select(BorrowerRegistrationRequest).where(
            BorrowerRegistrationRequest.id == registration_id
        )
    )
    reg = res.scalar_one_or_none()
    if reg is None:
        raise HTTPException(status_code=404, detail="Registration request not found")
    reg.status = "Rejected"
    reg.rejection_reason = reason
    reg.reviewed_at = datetime.now(UTC)
    reg.reviewed_by_user_id = current_user.id
    await db.commit()
    return {"message": "Registration request rejected"}


@router.get("/{borrower_id}", response_model=BorrowerResponse)
async def get_one_borrower(
    borrower_id: str,
    db: DbSession,
    current_user: CurrentUser,
) -> BorrowerResponse:
    """Return one non-deleted borrower by UUID."""
    del current_user
    borrower = await borrower_service.get_borrower(db, borrower_id)
    if borrower is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Borrower not found"
        )
    return BorrowerResponse.model_validate(borrower)


@router.post(
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
    if current_user.role not in ("officer", "manager", "admin", "owner"):
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


@router.put("/{borrower_id}", response_model=BorrowerResponse)
async def replace_borrower(
    borrower_id: str,
    payload: BorrowerUpdate,
    db: DbSession,
    current_user: CurrentUser,
) -> BorrowerResponse:
    """Update a borrower and write a redacted audit record."""
    borrower = await borrower_service.get_borrower(db, borrower_id)
    if borrower is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Borrower not found"
        )
    try:
        borrower = await borrower_service.update_borrower(
            db, borrower, payload, current_user
        )
        await db.commit()
    except IntegrityError as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="National ID or phone number already exists",
        ) from error
    await db.refresh(borrower)
    return BorrowerResponse.model_validate(borrower)


@router.delete("/{borrower_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_borrower(
    borrower_id: str,
    db: DbSession,
    current_user: CurrentUser,
) -> Response:
    """Soft-delete a borrower and write a redacted audit record."""
    borrower = await borrower_service.get_borrower(db, borrower_id)
    if borrower is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Borrower not found"
        )
    try:
        await borrower_service.delete_borrower(db, borrower, current_user)
    except borrower_service.BorrowerHasOpenLoansError as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(error),
        ) from error
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
