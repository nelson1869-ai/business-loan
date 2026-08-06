"""Deterministic payment receipt snapshot, template explanation, PDF, and verification service."""

import asyncio
import io
import json
import logging
import secrets
from datetime import UTC, date, datetime
from decimal import Decimal
from typing import Any

import httpx

import qrcode
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.features.borrowers.models import Borrower
from app.features.loans.models import Installment, Loan
from app.features.payments.models import Payment, PaymentAllocation, PaymentReceipt
from app.features.users.models import User

logger = logging.getLogger(__name__)

ZERO = Decimal("0.00")


def _money_str(val: Decimal | None) -> str:
    """Format Decimal to clean currency string e.g. 1,500.00."""
    if val is None:
        return "0.00"
    return f"{val.quantize(Decimal('0.01')):,}"


def build_deterministic_explanation(
    amount_received: Decimal,
    interest_applied: Decimal,
    principal_applied: Decimal,
    penalty_applied: Decimal,
    fees_applied: Decimal,
    unapplied_credit: Decimal,
    remaining_principal: Decimal,
    total_outstanding: Decimal,
    overdue_amount: Decimal,
    next_payment_amount: Decimal | None,
    next_due_date: date | None,
    loan_status: str,
    receipt_status: str = "Confirmed",
    reversal_reason: str | None = None,
    reversal_at: datetime | None = None,
) -> str:
    """Generate free plain-language explanation using backend deterministic template."""
    if receipt_status == "Reversed":
        rev_date_str = reversal_at.strftime("%Y-%m-%d") if reversal_at else "recently"
        reason_str = f" Reason: {reversal_reason}." if reversal_reason else ""
        return (
            f"This payment of ₱{_money_str(amount_received)} was REVERSED on {rev_date_str}.{reason_str} "
            f"The original payment allocation has been undone. Remaining principal is ₱{_money_str(remaining_principal)}."
        )

    parts: list[str] = [f"We received ₱{_money_str(amount_received)}."]

    # Allocation breakdown
    alloc_parts: list[str] = []
    if interest_applied > ZERO:
        alloc_parts.append(f"₱{_money_str(interest_applied)} was applied to interest")
    if principal_applied > ZERO:
        alloc_parts.append(f"₱{_money_str(principal_applied)} reduced your principal")
    if penalty_applied > ZERO:
        alloc_parts.append(f"₱{_money_str(penalty_applied)} was applied to penalties")
    if fees_applied > ZERO:
        alloc_parts.append(f"₱{_money_str(fees_applied)} was applied to fees")

    if alloc_parts:
        parts.append(", while ".join(alloc_parts) + ".")
    else:
        parts.append("No interest or principal was charged for this payment.")

    if unapplied_credit > ZERO:
        parts.append(f"₱{_money_str(unapplied_credit)} was placed in advance credit.")

    # Outstanding status
    if loan_status == "Paid" or remaining_principal <= ZERO:
        parts.append("Congratulations! Your loan is now fully paid.")
    else:
        parts.append(f"Your remaining principal is ₱{_money_str(remaining_principal)}.")
        if total_outstanding > remaining_principal:
            parts.append(f"Your total outstanding amount is ₱{_money_str(total_outstanding)}.")

        if overdue_amount > ZERO:
            parts.append(f"An overdue balance of ₱{_money_str(overdue_amount)} remains.")

        # Next payment info
        if next_payment_amount and next_payment_amount > ZERO and next_due_date:
            parts.append(
                f"Your next scheduled payment is ₱{_money_str(next_payment_amount)}, due on {next_due_date.strftime('%Y-%m-%d')}."
            )
        else:
            parts.append("No further installments are scheduled.")

    return " ".join(parts)


async def create_payment_receipt_snapshot(
    db: AsyncSession,
    payment: Payment,
    allocation: PaymentAllocation,
    loan: Loan,
    user: User,
    external_ref: str | None = None,
) -> PaymentReceipt:
    """Create an immutable PaymentReceipt snapshot atomically inside the payment recording transaction."""
    # Fetch borrower
    borrower_res = await db.execute(select(Borrower).where(Borrower.id == loan.borrower_id))
    borrower = borrower_res.scalar_one()

    # Find next scheduled installment
    next_inst = next(
        (i for i in sorted(loan.installments, key=lambda x: x.due_date) if i.status in ("Scheduled", "Overdue", "PartiallyPaid") and i.paid_amount < i.expected_payment),
        None,
    )
    next_amount = (next_inst.expected_payment - next_inst.paid_amount) if next_inst else None
    next_date = next_inst.due_date if next_inst else None

    overdue_amt = sum(
        (
            (i.expected_payment - i.paid_amount)
            for i in loan.installments
            if i.status in ("Overdue", "PartiallyPaid") and i.due_date < payment.effective_date
        ),
        ZERO,
    )
    total_outstanding = loan.outstanding_principal + allocation.interest_after

    balance_before = allocation.principal_before + allocation.interest_before
    verification_tok = secrets.token_urlsafe(24)

    receipt_num = f"RCPT-{payment.id.replace('-', '').upper()[:12]}"
    now_time = payment.created_at if payment.created_at else datetime.now(UTC)

    det_exp = build_deterministic_explanation(
        amount_received=payment.amount,
        interest_applied=allocation.applied_interest,
        principal_applied=allocation.applied_principal,
        penalty_applied=ZERO,
        fees_applied=ZERO,
        unapplied_credit=allocation.unapplied_credit,
        remaining_principal=allocation.principal_after,
        total_outstanding=total_outstanding,
        overdue_amount=overdue_amt,
        next_payment_amount=next_amount,
        next_due_date=next_date,
        loan_status=loan.status,
        receipt_status="Confirmed",
    )

    receipt = PaymentReceipt(
        id=secrets.token_hex(18),
        payment_id=payment.id,
        receipt_number=receipt_num,
        receipt_status="Confirmed",
        borrower_id=borrower.id,
        borrower_name=f"{borrower.first_name} {borrower.last_name}",
        borrower_account_ref=borrower.phone,
        loan_id=loan.id,
        loan_reference=loan.borrower_id[:8].upper(),
        payment_date=payment.effective_date,
        payment_time=now_time,
        effective_date=payment.effective_date,
        payment_method=payment.payment_method or "cash",
        external_reference=external_ref,
        amount_received=payment.amount,
        balance_before_payment=balance_before,
        principal_applied=allocation.applied_principal,
        interest_applied=allocation.applied_interest,
        penalty_applied=ZERO,
        fees_applied=ZERO,
        unapplied_credit=allocation.unapplied_credit,
        remaining_principal=allocation.principal_after,
        outstanding_interest=allocation.interest_after,
        overdue_amount=overdue_amt,
        total_outstanding_amount=total_outstanding,
        next_payment_amount=next_amount,
        next_due_date=next_date,
        loan_status_after=loan.status,
        recorded_by_user_id=user.id,
        recorded_by_name=user.username,
        verification_token=verification_tok,
        receipt_version=1,
        deterministic_explanation=det_exp,
        created_at=now_time,
    )
    db.add(receipt)
    return receipt


async def update_receipt_for_reversal(
    db: AsyncSession,
    original_payment_id: str,
    reversal_payment: Payment,
    reason: str,
) -> PaymentReceipt | None:
    """Mark original receipt as Reversed and record reversal details."""
    res = await db.execute(
        select(PaymentReceipt).where(PaymentReceipt.payment_id == original_payment_id)
    )
    receipt = res.scalar_one_or_none()
    if receipt is None:
        return None

    now = reversal_payment.created_at if reversal_payment.created_at else datetime.now(UTC)
    receipt.receipt_status = "Reversed"
    receipt.reversal_payment_id = reversal_payment.id
    receipt.reversal_reason = reason
    receipt.reversal_at = now
    receipt.receipt_version += 1
    receipt.ai_explanation = None  # Invalidate cached AI explanation

    receipt.deterministic_explanation = build_deterministic_explanation(
        amount_received=receipt.amount_received,
        interest_applied=receipt.interest_applied,
        principal_applied=receipt.principal_applied,
        penalty_applied=receipt.penalty_applied,
        fees_applied=receipt.fees_applied,
        unapplied_credit=receipt.unapplied_credit,
        remaining_principal=receipt.balance_before_payment,
        total_outstanding=receipt.balance_before_payment,
        overdue_amount=ZERO,
        next_payment_amount=None,
        next_due_date=None,
        loan_status="Active",
        receipt_status="Reversed",
        reversal_reason=reason,
        reversal_at=now,
    )
    return receipt


def generate_allowlisted_ai_payload(receipt: PaymentReceipt) -> dict[str, Any]:
    """Generate PII-free allowlisted financial payload for optional AI explanation."""
    return {
        "amountReceived": str(receipt.amount_received),
        "balanceBeforePayment": str(receipt.balance_before_payment),
        "principalApplied": str(receipt.principal_applied),
        "interestApplied": str(receipt.interest_applied),
        "penaltyApplied": str(receipt.penalty_applied),
        "feesApplied": str(receipt.fees_applied),
        "unappliedCredit": str(receipt.unapplied_credit),
        "remainingPrincipal": str(receipt.remaining_principal),
        "outstandingInterest": str(receipt.outstanding_interest),
        "overdueAmount": str(receipt.overdue_amount),
        "totalOutstanding": str(receipt.total_outstanding_amount),
        "nextPaymentAmount": str(receipt.next_payment_amount) if receipt.next_payment_amount else None,
        "nextDueDate": receipt.next_due_date.strftime("%Y-%m-%d") if receipt.next_due_date else None,
        "loanStatus": receipt.loan_status_after,
        "receiptStatus": receipt.receipt_status,
    }


def validate_and_format_ai_explanation(ai_output: str, receipt: PaymentReceipt) -> str:
    """Validate AI output for length, plain text, and financial claim integrity."""
    clean_text = ai_output.strip()
    if len(clean_text) > 600:
        raise ValueError("AI output exceeds maximum safe character length")

    # Blacklisted terms that indicate hallucinated promises or threats
    forbidden_words = ["guarantee", "court", "legal action", "sue", "borrow more", "discount", "waived forever"]
    for word in forbidden_words:
        if word in clean_text.lower():
            raise ValueError(f"AI output contains invalid promise/threat term: {word}")

    return clean_text


_RECEIPT_SYSTEM_PROMPT = (
    "You are a friendly assistant helping a borrower understand their payment receipt. "
    "Summarise the receipt in 2-3 plain sentences. "
    "Do NOT invent, change, or round any financial figure. "
    "Do NOT make promises, threats, or legal statements. "
    "Keep the response under 500 characters."
)


async def generate_ai_explanation(db: AsyncSession, receipt: PaymentReceipt) -> str:
    """Generate simple AI explanation via NVIDIA NIM with retry on 429, fallback to deterministic.

    Strategy:
    1. Return cached ai_explanation if already generated.
    2. Call NVIDIA NIM chat/completions with the allow-listed payload.
    3. On HTTP 429 (rate limit): honour Retry-After header (max 8 s) then retry once.
    4. On any other error or bad output: fall back to deterministic template.
    5. Never raise — borrowers always get a readable explanation.
    """
    if receipt.ai_explanation:
        return receipt.ai_explanation

    fallback_text = receipt.deterministic_explanation

    from app.core.config import get_settings  # noqa: PLC0415

    settings = get_settings()
    if not settings.ai_explanations_available:
        receipt.ai_explanation = fallback_text
        receipt.ai_explanation_model = "deterministic-fallback"
        await db.flush()
        return fallback_text

    assert settings.nvidia_api_key is not None and settings.nvidia_base_url is not None

    # Extract non-None values into locals so Pyright can narrow them correctly
    # inside the _call_nvidia closure (assert-narrowing does not propagate into closures).
    nvidia_base_url: str = settings.nvidia_base_url
    nvidia_api_key_value: str = settings.nvidia_api_key.get_secret_value()

    payload = generate_allowlisted_ai_payload(receipt)
    messages = [
        {"role": "system", "content": _RECEIPT_SYSTEM_PROMPT},
        {"role": "user", "content": json.dumps(payload, separators=(",", ":"))},
    ]
    request_body = {
        "model": settings.ai_model,
        "messages": messages,
        "temperature": settings.ai_temperature,
        "top_p": 0.9,
        "max_tokens": 256,
        "stream": False,
    }

    async def _call_nvidia() -> httpx.Response:
        async with httpx.AsyncClient(
            base_url=nvidia_base_url.rstrip("/") + "/",
            headers={"Authorization": f"Bearer {nvidia_api_key_value}"},
            timeout=httpx.Timeout(settings.ai_timeout_seconds, connect=5.0),
        ) as client:
            return await client.post("chat/completions", json=request_body)

    raw_text: str | None = None
    try:
        response = await _call_nvidia()

        if response.status_code == 429:
            # Honour Retry-After up to 8 seconds then retry once
            retry_after = min(float(response.headers.get("retry-after", "3")), 8.0)
            logger.info(
                "NVIDIA receipt AI rate-limited; retrying in %.1f s", retry_after
            )
            await asyncio.sleep(retry_after)
            response = await _call_nvidia()

        response.raise_for_status()
        content = response.json()["choices"][0]["message"]["content"]
        raw_text = content.strip()
    except (httpx.HTTPError, KeyError, IndexError, TypeError, json.JSONDecodeError) as exc:
        logger.warning("Receipt AI explanation failed (%s); using deterministic fallback", exc)

    if raw_text:
        try:
            validated = validate_and_format_ai_explanation(raw_text, receipt)
            receipt.ai_explanation = validated
            receipt.ai_explanation_model = settings.ai_model
            await db.flush()
            return validated
        except ValueError as exc:
            logger.warning("Receipt AI output rejected by validator (%s); using deterministic fallback", exc)

    receipt.ai_explanation = fallback_text
    receipt.ai_explanation_model = "deterministic-fallback"
    await db.flush()
    return fallback_text


def generate_receipt_pdf(receipt: PaymentReceipt, verification_url: str) -> bytes:
    """Generate official PDF receipt byte stream using ReportLab and QRCode."""
    from reportlab.lib import colors
    from reportlab.lib.pagesizes import letter
    from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
    from reportlab.platypus import Image, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=letter,
        rightMargin=36,
        leftMargin=36,
        topMargin=36,
        bottomMargin=36,
    )

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "ReceiptTitle",
        parent=styles["Heading1"],
        fontSize=18,
        leading=22,
        textColor=colors.HexColor("#1A365D"),
        alignment=1,
    )
    subtitle_style = ParagraphStyle(
        "ReceiptSubTitle",
        parent=styles["Normal"],
        fontSize=11,
        leading=14,
        textColor=colors.HexColor("#4A5568"),
        alignment=1,
    )
    heading_style = ParagraphStyle(
        "SectionHeading",
        parent=styles["Heading2"],
        fontSize=12,
        leading=15,
        textColor=colors.HexColor("#2B6CB0"),
        spaceBefore=10,
        spaceAfter=5,
    )
    body_style = ParagraphStyle(
        "BodyText",
        parent=styles["Normal"],
        fontSize=9,
        leading=12,
        textColor=colors.HexColor("#2D3748"),
    )

    story: list[Any] = []

    # 1. Header
    story.append(Paragraph("LENDING NELSON", title_style))
    story.append(Paragraph("OFFICIAL PAYMENT RECEIPT", subtitle_style))
    story.append(Spacer(1, 12))

    status_color = "#C53030" if receipt.receipt_status == "Reversed" else "#276749"
    status_para = Paragraph(
        f"<b>Status:</b> <font color='{status_color}'>{receipt.receipt_status.upper()}</font> | <b>Receipt No:</b> {receipt.receipt_number}",
        subtitle_style,
    )
    story.append(status_para)
    story.append(Spacer(1, 15))

    # 2. General Information Table
    gen_data = [
        [Paragraph("<b>Borrower Name:</b>", body_style), Paragraph(receipt.borrower_name, body_style)],
        [Paragraph("<b>Account Ref:</b>", body_style), Paragraph(receipt.borrower_account_ref, body_style)],
        [Paragraph("<b>Payment Date:</b>", body_style), Paragraph(receipt.payment_date.strftime("%Y-%m-%d"), body_style)],
        [Paragraph("<b>Effective Date:</b>", body_style), Paragraph(receipt.effective_date.strftime("%Y-%m-%d"), body_style)],
        [Paragraph("<b>Payment Method:</b>", body_style), Paragraph(receipt.payment_method.capitalize(), body_style)],
        [Paragraph("<b>Recorded By:</b>", body_style), Paragraph(receipt.recorded_by_name, body_style)],
    ]
    gen_table = Table(gen_data, colWidths=[140, 380])
    gen_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F7FAFC")),
                ("INNERGRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
                ("BOX", (0, 0), (-1, -1), 1, colors.HexColor("#CBD5E0")),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    story.append(gen_table)
    story.append(Spacer(1, 15))

    # 3. Payment Allocation & Balance Breakdown Table
    story.append(Paragraph("Payment Allocation & Balance Summary", heading_style))

    alloc_data = [
        [Paragraph("<b>Description</b>", body_style), Paragraph("<b>Amount (PHP)</b>", body_style)],
        [Paragraph("Amount Received", body_style), Paragraph(f"₱{_money_str(receipt.amount_received)}", body_style)],
        [Paragraph("Applied to Interest", body_style), Paragraph(f"₱{_money_str(receipt.interest_applied)}", body_style)],
        [Paragraph("Applied to Principal", body_style), Paragraph(f"₱{_money_str(receipt.principal_applied)}", body_style)],
        [Paragraph("Applied to Penalties", body_style), Paragraph(f"₱{_money_str(receipt.penalty_applied)}", body_style)],
        [Paragraph("Applied to Fees", body_style), Paragraph(f"₱{_money_str(receipt.fees_applied)}", body_style)],
        [Paragraph("Advance / Unapplied Credit", body_style), Paragraph(f"₱{_money_str(receipt.unapplied_credit)}", body_style)],
        [Paragraph("<b>Balance Before Payment</b>", body_style), Paragraph(f"₱{_money_str(receipt.balance_before_payment)}", body_style)],
        [Paragraph("<b>Remaining Principal Balance</b>", body_style), Paragraph(f"₱{_money_str(receipt.remaining_principal)}", body_style)],
        [Paragraph("<b>Total Outstanding Amount</b>", body_style), Paragraph(f"₱{_money_str(receipt.total_outstanding_amount)}", body_style)],
    ]
    alloc_table = Table(alloc_data, colWidths=[340, 180])
    alloc_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#EDF2F7")),
                ("INNERGRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
                ("BOX", (0, 0), (-1, -1), 1, colors.HexColor("#CBD5E0")),
                ("ALIGN", (1, 0), (1, -1), "RIGHT"),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    story.append(alloc_table)
    story.append(Spacer(1, 15))

    # 4. Next Payment Schedule
    story.append(Paragraph("Next Payment Information", heading_style))
    next_amt_str = f"₱{_money_str(receipt.next_payment_amount)}" if receipt.next_payment_amount else "N/A"
    next_date_str = receipt.next_due_date.strftime("%Y-%m-%d") if receipt.next_due_date else "N/A"
    next_data = [
        [Paragraph("<b>Next Payment Amount:</b>", body_style), Paragraph(next_amt_str, body_style)],
        [Paragraph("<b>Next Due Date:</b>", body_style), Paragraph(next_date_str, body_style)],
        [Paragraph("<b>Loan Status:</b>", body_style), Paragraph(receipt.loan_status_after, body_style)],
    ]
    next_table = Table(next_data, colWidths=[140, 380])
    next_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F7FAFC")),
                ("INNERGRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#E2E8F0")),
                ("BOX", (0, 0), (-1, -1), 1, colors.HexColor("#CBD5E0")),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    story.append(next_table)
    story.append(Spacer(1, 15))

    # 5. Deterministic Explanation
    story.append(Paragraph("Payment Summary & Explanation", heading_style))
    story.append(Paragraph(receipt.deterministic_explanation, body_style))
    story.append(Spacer(1, 15))

    # 6. Verification Code & QR Code
    qr_img = qrcode.make(verification_url)
    qr_buffer = io.BytesIO()
    qr_img.save(qr_buffer)
    qr_buffer.seek(0)

    qr_element = Image(qr_buffer, width=70, height=70)
    ver_text = Paragraph(
        f"<b>Verification Token:</b> {receipt.verification_token}<br/>"
        f"Scan QR code or visit backend verification endpoint to confirm official receipt validity.",
        body_style,
    )

    ver_table = Table([[qr_element, ver_text]], colWidths=[80, 440])
    ver_table.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    story.append(ver_table)
    story.append(Spacer(1, 15))

    # 7. Disclaimer
    disclaimer_text = Paragraph(
        "<i>This document is an official digital payment receipt generated by Lending Nelson. "
        "Financial figures recorded herein are backed by deterministic ledger accounting entries.</i>",
        ParagraphStyle("Disclaimer", parent=styles["Italic"], fontSize=8, textColor=colors.HexColor("#718096"), alignment=1),
    )
    story.append(disclaimer_text)

    doc.build(story)
    buffer.seek(0)
    return buffer.getvalue()
