"""Tests for Payment Receipts, Deterministic Explanations, PDF Generation, Verification, and Notifications."""

from datetime import UTC, date, datetime, timedelta
from decimal import Decimal

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.core.database import AsyncSessionFactory, get_db
from app.features.auth.service import create_token, hash_password
from app.features.payments.receipt_service import (
    build_deterministic_explanation,
    generate_allowlisted_ai_payload,
    generate_receipt_pdf,
    validate_and_format_ai_explanation,
)
from app.features.users.models import User
from app.main import app

pytestmark = pytest.mark.anyio


@pytest.fixture
async def client():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as ac:
        yield ac


@pytest.fixture
async def officer_token():
    """Create owner access token in-memory."""
    user = User(
        id="receipt-owner-uuid",
        username="receipt_owner_test",
        hashed_password=hash_password("OwnerPass123!"),
        role="owner",
    )
    async with AsyncSessionFactory() as db:
        existing = await db.get(User, "receipt-owner-uuid")
        if existing is None:
            db.add(user)
            await db.commit()
    return create_token(user, "access")


def test_deterministic_explanation_formatting():
    """Verify template logic across allocation scenarios."""
    # 1. Standard payment
    exp1 = build_deterministic_explanation(
        amount_received=Decimal("1500.00"),
        interest_applied=Decimal("300.00"),
        principal_applied=Decimal("1200.00"),
        penalty_applied=Decimal("0.00"),
        fees_applied=Decimal("0.00"),
        unapplied_credit=Decimal("0.00"),
        remaining_principal=Decimal("6800.00"),
        total_outstanding=Decimal("6800.00"),
        overdue_amount=Decimal("0.00"),
        next_payment_amount=Decimal("1500.00"),
        next_due_date=date(2026, 8, 20),
        loan_status="Active",
    )
    assert "We received ₱1,500.00." in exp1
    assert "₱300.00 was applied to interest" in exp1
    assert "₱1,200.00 reduced your principal" in exp1
    assert "remaining principal is ₱6,800.00" in exp1
    assert "due on 2026-08-20" in exp1

    # 2. Fully paid loan
    exp2 = build_deterministic_explanation(
        amount_received=Decimal("5000.00"),
        interest_applied=Decimal("500.00"),
        principal_applied=Decimal("4500.00"),
        penalty_applied=Decimal("0.00"),
        fees_applied=Decimal("0.00"),
        unapplied_credit=Decimal("0.00"),
        remaining_principal=Decimal("0.00"),
        total_outstanding=Decimal("0.00"),
        overdue_amount=Decimal("0.00"),
        next_payment_amount=None,
        next_due_date=None,
        loan_status="Paid",
    )
    assert "Congratulations! Your loan is now fully paid." in exp2

    # 3. Reversed payment
    exp3 = build_deterministic_explanation(
        amount_received=Decimal("1500.00"),
        interest_applied=Decimal("300.00"),
        principal_applied=Decimal("1200.00"),
        penalty_applied=Decimal("0.00"),
        fees_applied=Decimal("0.00"),
        unapplied_credit=Decimal("0.00"),
        remaining_principal=Decimal("8000.00"),
        total_outstanding=Decimal("8000.00"),
        overdue_amount=Decimal("0.00"),
        next_payment_amount=None,
        next_due_date=None,
        loan_status="Active",
        receipt_status="Reversed",
        reversal_reason="Mistaken payment entry",
        reversal_at=datetime.now(UTC),
    )
    assert "REVERSED" in exp3
    assert "Mistaken payment entry" in exp3


def test_ai_explanation_validation_rules():
    """Verify AI output validation limits and rules."""
    class DummyReceipt:
        amount_received = Decimal("1000.00")

    # Safe text passes
    valid_text = validate_and_format_ai_explanation("You paid 1000 pesos cleanly.", DummyReceipt())
    assert valid_text == "You paid 1000 pesos cleanly."

    # Forbidden promises fail
    with pytest.raises(ValueError, match="invalid promise"):
        validate_and_format_ai_explanation("We guarantee to take court legal action if you do not pay.", DummyReceipt())


@pytest.mark.anyio
async def test_payment_receipt_end_to_end(client: AsyncClient, officer_token: str):
    """End-to-end test of payment recording, receipt snapshot creation, public verification, and PDF streaming."""
    from uuid import uuid4

    uid = uuid4().hex[:6]
    phone = f"0918{uid}00000"[:11]
    nat_id = f"NAT-RC-{uid}"

    headers = {"Authorization": f"Bearer {officer_token}"}

    # 1. Create borrower
    b_id = str(uuid4())
    b_resp = await client.post(
        "/api/v1/borrowers",
        headers=headers,
        json={
            "id": b_id,
            "firstName": "Receipt",
            "lastName": "TestBorrower",
            "nationalId": nat_id,
            "phone": phone,
            "dateOfBirth": "1990-01-01",
            "createdAt": datetime.now(UTC).isoformat(),
        },
    )
    assert b_resp.status_code == 201, f"Borrower create failed: {b_resp.text}"
    borrower_id = b_resp.json()["id"]

    # 2. Create approved active loan
    loan_resp = await client.post(
        "/api/v1/loans",
        headers=headers,
        json={
            "id": str(uuid4()),
            "borrowerId": borrower_id,
            "originalPrincipal": "10000.00",
            "monthlyRate": "0.05",
            "termMonths": 2,
            "paymentsPerMonth": 1,
            "startDate": "2026-08-01",
            "firstDueDate": "2026-09-01",
        },
    )
    assert loan_resp.status_code == 201, f"Loan create failed: {loan_resp.text}"
    loan_id = loan_resp.json()["id"]

    # 3. Check for existing open collection session for this collector or create one
    cs_list_resp = await client.get("/api/v1/collection-sessions?status=open", headers=headers)
    raw_items = cs_list_resp.json() if isinstance(cs_list_resp.json(), list) else cs_list_resp.json().get("items", [])
    my_open_items = [item for item in raw_items if item.get("collectorUserId") == "receipt-owner-uuid"]
    if my_open_items:
        cs_id = my_open_items[0]["id"]
    else:
        cs_resp = await client.post(
            "/api/v1/collection-sessions",
            headers=headers,
            json={
                "id": str(uuid4()),
                "collectorUserId": "receipt-owner-uuid",
                "assignedDate": "2026-08-05",
                "openingCash": "0.00",
            },
        )
        assert cs_resp.status_code == 201, f"CS create failed: {cs_resp.text}"
        cs_id = cs_resp.json()["id"]

    # 4. Record payment
    req_id = str(uuid4())
    pmt_resp = await client.post(
        f"/api/v1/loans/{loan_id}/payments",
        headers=headers,
        json={
            "requestId": req_id,
            "amount": "2500.00",
            "effectiveDate": "2026-08-05",
            "paymentMethod": "cash",
            "collectionSessionId": cs_id,
            "receiptNumber": f"CASH-RC-{uid}",
        },
    )
    assert pmt_resp.status_code == 201, f"Pmt create failed: {pmt_resp.text}"
    pmt_id = pmt_resp.json()["id"]

    # 5. Fetch Owner receipt snapshot
    rcpt_resp = await client.get(
        f"/api/v1/owner/receipts/by-payment/{pmt_id}",
        headers=headers,
    )
    assert rcpt_resp.status_code == 200
    rcpt_data = rcpt_resp.json()
    assert rcpt_data["amount_received"] == "2500.00"
    assert rcpt_data["receipt_status"] == "Confirmed"
    v_token = rcpt_data["verification_token"]

    # 6. Verify public non-PII token
    pub_resp = await client.get(f"/api/v1/public/receipts/verify/{v_token}")
    assert pub_resp.status_code == 200
    pub_data = pub_resp.json()
    assert pub_data["is_valid"] is True
    assert pub_data["business_identity"] == "Lending Nelson"
    assert pub_data["amount_received"] == "2500.00"

    # 7. Download PDF
    pdf_resp = await client.get(f"/api/v1/owner/receipts/{rcpt_data['id']}/pdf", headers=headers)
    assert pdf_resp.status_code == 200
    assert pdf_resp.headers["content-type"] == "application/pdf"
    assert pdf_resp.content.startswith(b"%PDF")
