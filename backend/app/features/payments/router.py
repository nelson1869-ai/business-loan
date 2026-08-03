"""Authenticated payment preview, confirmation, and history routes."""

from datetime import UTC, datetime
from typing import Any

from fastapi import APIRouter, HTTPException, status
from sqlalchemy.exc import IntegrityError

from app.core.authorization import require_any_permission, require_permission
from app.core.dependencies import CurrentUser, DbSession
from app.features.accounting.service import (
    post_journal,
    repayment_lines,
    reversing_lines,
)
from app.features.approvals.service import consume_approved_request
from app.features.automation.outbox import process_outbox_batch, publish_outbox_event
from app.features.automation.schemas import DomainEventEnvelope, EventActor, EventEntity
from app.features.loans import service as loan_service
from app.features.loans.calculator import LoanCalculationError
from app.features.payments import service as payment_service
from app.features.payments.schemas import (
    PaymentCreate,
    PaymentPage,
    PaymentPreviewRequest,
    PaymentPreviewResponse,
    PaymentResponse,
    PaymentReversalCreate,
    PaymentReversalResponse,
)

router = APIRouter(prefix="/api/v1/loans/{loan_id}/payments", tags=["Payments"])


@router.post("/preview", response_model=PaymentPreviewResponse)
async def preview_one_payment(
    loan_id: str,
    payload: PaymentPreviewRequest,
    db: DbSession,
    current_user: CurrentUser,
) -> PaymentPreviewResponse:
    require_permission(current_user, "payment.collect")
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
    require_permission(current_user, "payment.collect")
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
        await post_journal(
            db,
            actor=current_user,
            currency="PHP",
            posted_at=datetime.now(UTC),
            source_type="payment",
            source_record_id=payment.id,
            idempotency_key=f"payment:{payload.request_id}",
            request_id=payload.request_id,
            description=f"Payment received for loan {loan_id}",
            lines=repayment_lines(
                amount=payment.amount,
                principal=payment.allocation.applied_principal,
                interest=payment.allocation.applied_interest,
                unapplied_credit=payment.allocation.unapplied_credit,
            ),
        )
        envelope = DomainEventEnvelope[dict[str, Any]](
            eventType="payment.received",
            idempotencyKey=f"payment.received:{payment.id}",
            actor=EventActor(
                id=current_user.id, role=getattr(current_user, "role", "officer")
            ),
            entity=EventEntity(type="payment", id=payment.id),
            data={
                "payment_id": payment.id,
                "loan_id": loan_id,
                "borrower_id": payment.loan.borrower_id if payment.loan else "",
                "amount_paid": str(payload.amount),
                "remaining_balance": str(
                    payment.loan.outstanding_principal if payment.loan else "0.00"
                ),
                "effective_date": payload.effective_date.isoformat(),
                "note": payload.note,
            },
        )
        await publish_outbox_event(db, envelope)
        await db.commit()
        await process_outbox_batch(db, limit=5)
    except (LoanCalculationError, ValueError) as error:
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
    require_any_permission(current_user, {"payment.collect", "payment.reverse"})
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
    if payload.approval_request_id is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="An approved maker-checker request is required",
        )
    try:
        await consume_approved_request(
            db,
            request_id=payload.approval_request_id,
            action="payment.reverse",
            entity_type="payment",
            entity_id=payment_id,
            maker=current_user,
        )
        reversal = await payment_service.reverse_latest_payment(
            db, loan_id, payment_id, payload, current_user
        )
        allocation = reversal.allocation
        original_lines = repayment_lines(
            amount=reversal.amount,
            principal=allocation.applied_principal,
            interest=allocation.applied_interest,
            unapplied_credit=allocation.unapplied_credit,
        )
        await post_journal(
            db,
            actor=current_user,
            currency="PHP",
            posted_at=datetime.now(UTC),
            source_type="payment_reversal",
            source_record_id=reversal.id,
            idempotency_key=f"payment-reversal:{payload.request_id}",
            request_id=payload.request_id,
            description=f"Reversal of payment {payment_id}",
            lines=reversing_lines(original_lines),
        )
        await db.commit()
    except PermissionError as error:
        await db.rollback()
        raise HTTPException(status_code=403, detail=str(error)) from error
    except (LoanCalculationError, ValueError) as error:
        await db.rollback()
        existing = await payment_service.get_payment_by_request_id(
            db, payload.request_id
        )
        if existing is not None and payment_service.reversal_matches_request(
            existing, loan_id, payment_id, payload
        ):
            return PaymentReversalResponse.model_validate(existing)
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
