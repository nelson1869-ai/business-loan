"""Authenticated payment preview, confirmation, and history routes."""

from fastapi import APIRouter, HTTPException, status
from sqlalchemy.exc import IntegrityError

from app.dependencies import CurrentUser, DbSession
from app.schemas.payment import (
    PaymentCreate,
    PaymentPage,
    PaymentPreviewRequest,
    PaymentPreviewResponse,
    PaymentResponse,
    PaymentReversalCreate,
    PaymentReversalResponse,
)
from app.services import loan_service, payment_service
from app.services.loan_calculator import LoanCalculationError
from app.services.webhook_service import dispatch_n8n_event

router = APIRouter(prefix="/api/v1/loans/{loan_id}/payments", tags=["Payments"])


@router.post("/preview", response_model=PaymentPreviewResponse)
async def preview_one_payment(
    loan_id: str,
    payload: PaymentPreviewRequest,
    db: DbSession,
    current_user: CurrentUser,
) -> PaymentPreviewResponse:
    del current_user
    try:
        preview = await payment_service.preview_payment(db, loan_id, payload)
        await db.rollback()
        return preview
    except LoanCalculationError as error:
        await db.rollback()
        code = (
            status.HTTP_404_NOT_FOUND
            if "not found" in str(error)
            else status.HTTP_409_CONFLICT
        )
        raise HTTPException(status_code=code, detail=str(error)) from error


@router.post("", response_model=PaymentResponse, status_code=status.HTTP_201_CREATED)
async def confirm_one_payment(
    loan_id: str,
    payload: PaymentCreate,
    db: DbSession,
    current_user: CurrentUser,
) -> PaymentResponse:
    existing = await payment_service.get_payment_by_request_id(db, payload.request_id)
    if existing is not None:
        if not payment_service.payment_matches_request(existing, loan_id, payload):
            raise HTTPException(
                status_code=409,
                detail="Request ID was already used for a different payment",
            )
        return PaymentResponse.model_validate(existing)
    try:
        payment = await payment_service.record_payment(
            db, loan_id, payload, current_user
        )
        await db.commit()
        await dispatch_n8n_event(
            "payment_recorded",
            {
                "payment_id": payment.id,
                "loan_id": loan_id,
                "amount_paid": float(payload.amount),
                "recorded_by": current_user.username,
            },
        )
    except LoanCalculationError as error:
        await db.rollback()
        code = (
            status.HTTP_404_NOT_FOUND
            if "not found" in str(error)
            else status.HTTP_409_CONFLICT
        )
        raise HTTPException(status_code=code, detail=str(error)) from error
    except IntegrityError as error:
        await db.rollback()
        existing = await payment_service.get_payment_by_request_id(
            db, payload.request_id
        )
        if existing is not None and payment_service.payment_matches_request(
            existing, loan_id, payload
        ):
            return PaymentResponse.model_validate(existing)
        raise HTTPException(
            status_code=409, detail="Payment request conflicts with existing data"
        ) from error
    reloaded = await payment_service.get_payment(db, payment.id)
    if reloaded is None:
        raise HTTPException(
            status_code=500, detail="Created payment could not be reloaded"
        )
    return PaymentResponse.model_validate(reloaded)


@router.get("", response_model=list[PaymentResponse])
async def list_loan_payments(
    loan_id: str,
    db: DbSession,
    current_user: CurrentUser,
) -> list[PaymentResponse]:
    del current_user
    if await loan_service.get_loan(db, loan_id) is None:
        raise HTTPException(status_code=404, detail="Loan not found")
    return [
        PaymentResponse.model_validate(item)
        for item in await payment_service.list_payments(db, loan_id)
    ]


@router.get("/page", response_model=PaymentPage)
async def page_loan_payments(
    loan_id: str,
    db: DbSession,
    current_user: CurrentUser,
    offset: int = 0,
    limit: int = 50,
) -> PaymentPage:
    """Return a stable paginated payment envelope."""
    del current_user
    if offset < 0 or limit < 1 or limit > 200:
        raise HTTPException(
            status_code=422, detail="offset/limit outside allowed range"
        )
    if await loan_service.get_loan(db, loan_id) is None:
        raise HTTPException(status_code=404, detail="Loan not found")
    items, total = await payment_service.page_payments(db, loan_id, offset, limit)
    return PaymentPage(
        items=[PaymentResponse.model_validate(item) for item in items],
        total=total,
        offset=offset,
        limit=limit,
    )


@router.post(
    "/{payment_id}/reversal",
    response_model=PaymentReversalResponse,
    status_code=status.HTTP_201_CREATED,
)
async def reverse_one_payment(
    loan_id: str,
    payment_id: str,
    payload: PaymentReversalCreate,
    db: DbSession,
    current_user: CurrentUser,
) -> PaymentReversalResponse:
    """Reverse the latest payment without deleting its ledger history."""
    existing = await payment_service.get_payment_by_request_id(db, payload.request_id)
    if existing is not None:
        if not payment_service.reversal_matches_request(
            existing, loan_id, payment_id, payload
        ):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Request ID was already used for a different entry",
            )
        return PaymentReversalResponse.model_validate(existing)
    try:
        reversal = await payment_service.reverse_latest_payment(
            db, loan_id, payment_id, payload, current_user
        )
        await db.commit()
    except LoanCalculationError as error:
        await db.rollback()
        code = (
            status.HTTP_404_NOT_FOUND
            if "not found" in str(error)
            else status.HTTP_409_CONFLICT
        )
        raise HTTPException(status_code=code, detail=str(error)) from error
    except IntegrityError as error:
        await db.rollback()
        existing = await payment_service.get_payment_by_request_id(
            db, payload.request_id
        )
        if existing is not None and payment_service.reversal_matches_request(
            existing, loan_id, payment_id, payload
        ):
            return PaymentReversalResponse.model_validate(existing)
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Reversal request conflicts with existing data",
        ) from error
    reloaded = await payment_service.get_payment(db, reversal.id)
    if reloaded is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Created reversal could not be reloaded",
        )
    return PaymentReversalResponse.model_validate(reloaded)
