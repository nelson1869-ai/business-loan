"""API router for Payment Receipts, Verification, PDF Streaming, and Notifications."""

from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.core.dependencies import CurrentUser
from app.features.borrower_portal.dependencies import ActiveBorrowerAccount
from app.features.borrower_portal.models import BorrowerAccount, BorrowerNotification
from app.features.payments.models import PaymentReceipt
from app.features.payments.receipt_schemas import (
    AIExplanationResponse,
    BorrowerNotificationResponse,
    PaymentReceiptResponse,
    PublicReceiptVerificationResponse,
)
from app.features.payments.receipt_service import (
    generate_ai_explanation,
    generate_allowlisted_ai_payload,
    generate_receipt_pdf,
    validate_and_format_ai_explanation,
)

public_router = APIRouter(prefix="/api/v1/public/receipts", tags=["Public Receipt Verification"])
client_receipt_router = APIRouter(prefix="/api/v1/client/me", tags=["Borrower Client Receipts"])
officer_receipt_router = APIRouter(prefix="/api/v1/payments/receipts", tags=["Officer Receipts"])

DbSession = Annotated[AsyncSession, Depends(get_db)]


@public_router.get(
    "/verify/{verification_token}",
    response_model=PublicReceiptVerificationResponse,
)
async def verify_receipt_token(
    verification_token: str,
    db: DbSession,
) -> PublicReceiptVerificationResponse:
    """Public read-only receipt verification endpoint returning non-PII information."""
    stmt = select(PaymentReceipt).where(
        PaymentReceipt.verification_token == verification_token
    )
    res = await db.execute(stmt)
    receipt = res.scalar_one_or_none()

    if receipt is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Receipt verification code is invalid or not found",
        )

    now = datetime.now(UTC)
    return PublicReceiptVerificationResponse(
        is_valid=True,
        receipt_number=receipt.receipt_number,
        receipt_status=receipt.receipt_status,
        amount_received=receipt.amount_received,
        payment_date=receipt.payment_date,
        effective_date=receipt.effective_date,
        business_identity="Lending Nelson",
        verified_at=now,
    )


@client_receipt_router.get(
    "/receipts/{receipt_id}",
    response_model=PaymentReceiptResponse,
)
async def get_borrower_receipt_by_id(
    receipt_id: str,
    db: DbSession,
    current_account: ActiveBorrowerAccount,
) -> PaymentReceiptResponse:
    """Fetch borrower-scoped detailed receipt snapshot."""
    stmt = select(PaymentReceipt).where(
        PaymentReceipt.id == receipt_id,
        PaymentReceipt.borrower_id == current_account.borrower_id,
    )
    res = await db.execute(stmt)
    receipt = res.scalar_one_or_none()

    if receipt is None:
        # Fallback check by payment_id
        stmt_pmt = select(PaymentReceipt).where(
            PaymentReceipt.payment_id == receipt_id,
            PaymentReceipt.borrower_id == current_account.borrower_id,
        )
        receipt = (await db.execute(stmt_pmt)).scalar_one_or_none()

    if receipt is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Receipt record not found",
        )

    return PaymentReceiptResponse.model_validate(receipt)


@client_receipt_router.get("/receipts/{receipt_id}/pdf")
async def get_borrower_receipt_pdf(
    receipt_id: str,
    request: Request,
    db: DbSession,
    current_account: ActiveBorrowerAccount,
) -> Response:
    """Generate and stream official PDF receipt for borrower."""
    stmt = select(PaymentReceipt).where(
        PaymentReceipt.id == receipt_id,
        PaymentReceipt.borrower_id == current_account.borrower_id,
    )
    res = await db.execute(stmt)
    receipt = res.scalar_one_or_none()

    if receipt is None:
        stmt_pmt = select(PaymentReceipt).where(
            PaymentReceipt.payment_id == receipt_id,
            PaymentReceipt.borrower_id == current_account.borrower_id,
        )
        receipt = (await db.execute(stmt_pmt)).scalar_one_or_none()

    if receipt is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Receipt record not found",
        )

    base_url = str(request.base_url).rstrip("/")
    verification_url = f"{base_url}/api/v1/public/receipts/verify/{receipt.verification_token}"
    pdf_bytes = generate_receipt_pdf(receipt, verification_url)

    filename = f"{receipt.receipt_number}.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@client_receipt_router.post(
    "/receipts/{receipt_id}/explanation",
    response_model=AIExplanationResponse,
)
async def request_ai_explanation(
    receipt_id: str,
    db: DbSession,
    current_account: ActiveBorrowerAccount,
) -> AIExplanationResponse:
    """Generate or retrieve simplified explanation for borrower receipt with fallback."""
    stmt = select(PaymentReceipt).where(
        PaymentReceipt.id == receipt_id,
        PaymentReceipt.borrower_id == current_account.borrower_id,
    )
    res = await db.execute(stmt)
    receipt = res.scalar_one_or_none()

    if receipt is None:
        stmt_pmt = select(PaymentReceipt).where(
            PaymentReceipt.payment_id == receipt_id,
            PaymentReceipt.borrower_id == current_account.borrower_id,
        )
        receipt = (await db.execute(stmt_pmt)).scalar_one_or_none()

    if receipt is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Receipt record not found",
        )

    if receipt.ai_explanation:
        return AIExplanationResponse(
            receipt_id=receipt.id,
            explanation=receipt.ai_explanation,
            is_ai_generated=True,
        )

    # Use deterministic explanation directly as safe fallback
    return AIExplanationResponse(
        receipt_id=receipt.id,
        explanation=receipt.deterministic_explanation,
        is_ai_generated=False,
    )


@client_receipt_router.get(
    "/notifications",
    response_model=list[BorrowerNotificationResponse],
)
async def list_borrower_notifications(
    db: DbSession,
    current_account: ActiveBorrowerAccount,
) -> list[BorrowerNotificationResponse]:
    """Fetch borrower in-app notifications."""
    stmt = (
        select(BorrowerNotification)
        .where(BorrowerNotification.borrower_id == current_account.borrower_id)
        .order_by(BorrowerNotification.created_at.desc())
    )
    res = await db.execute(stmt)
    notifications = list(res.scalars().all())
    return [BorrowerNotificationResponse.model_validate(n) for n in notifications]


@client_receipt_router.post("/notifications/{notification_id}/read")
async def mark_notification_read(
    notification_id: str,
    db: DbSession,
    current_account: ActiveBorrowerAccount,
) -> dict[str, str]:
    """Mark an in-app notification as read."""
    stmt = select(BorrowerNotification).where(
        BorrowerNotification.id == notification_id,
        BorrowerNotification.borrower_id == current_account.borrower_id,
    )
    res = await db.execute(stmt)
    notification = res.scalar_one_or_none()
    if notification:
        notification.is_read = True
        await db.commit()
    return {"message": "Notification marked as read"}


@officer_receipt_router.get(
    "/by-payment/{payment_id}",
    response_model=PaymentReceiptResponse,
)
async def get_officer_receipt_by_payment(
    payment_id: str,
    db: DbSession,
    current_user: CurrentUser,
) -> PaymentReceiptResponse:
    """Owner/Officer endpoint to view receipt snapshot by payment UUID."""
    if current_user.role not in ("admin", "owner", "manager", "officer"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions",
        )
    stmt = select(PaymentReceipt).where(PaymentReceipt.payment_id == payment_id)
    res = await db.execute(stmt)
    receipt = res.scalar_one_or_none()

    if receipt is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Payment receipt not found",
        )
    return PaymentReceiptResponse.model_validate(receipt)


@officer_receipt_router.get("/{receipt_id}/pdf")
async def get_officer_receipt_pdf(
    receipt_id: str,
    request: Request,
    db: DbSession,
    current_user: CurrentUser,
) -> Response:
    """Owner/Officer endpoint to download PDF receipt by receipt ID or payment ID."""
    if current_user.role not in ("admin", "owner", "manager", "officer"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permissions",
        )
    stmt = select(PaymentReceipt).where(PaymentReceipt.id == receipt_id)
    res = await db.execute(stmt)
    receipt = res.scalar_one_or_none()

    if receipt is None:
        stmt_pmt = select(PaymentReceipt).where(PaymentReceipt.payment_id == receipt_id)
        receipt = (await db.execute(stmt_pmt)).scalar_one_or_none()

    if receipt is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Receipt record not found",
        )

    base_url = str(request.base_url).rstrip("/")
    verification_url = f"{base_url}/api/v1/public/receipts/verify/{receipt.verification_token}"
    pdf_bytes = generate_receipt_pdf(receipt, verification_url)

    filename = f"{receipt.receipt_number}.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
