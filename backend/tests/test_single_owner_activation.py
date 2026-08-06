"""Tests for Single-Owner Borrower Registration, Activation Code Generation, Activation Redemption, PIN Login, and Loan Requests."""

import pytest
from datetime import UTC, datetime, date
from decimal import Decimal
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from app.main import app
from app.core.database import Base, engine, AsyncSessionFactory
from app.features.users.models import User
from app.features.auth.service import create_token, hash_password
from app.features.borrower_portal.models import (
    BorrowerAccount,
    BorrowerActivationCode,
    BorrowerLoanRequest,
    BorrowerRegistrationRequest,
)

pytestmark = pytest.mark.anyio


@pytest.fixture
async def client():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as ac:
        yield ac


@pytest.fixture
def owner_token():
    """Create single-owner access token in-memory."""
    owner = User(
        id="owner-test-uuid",
        username="owner_test",
        hashed_password=hash_password("OwnerSecret123!"),
        role="owner",
    )
    return create_token(owner, "access")


async def test_single_owner_registration_and_activation_flow(
    client: AsyncClient, owner_token: str
):
    """Test full workflow: Public Registration -> Owner Approval -> 6-Digit Activation Code -> Activation Redemption -> PIN Login."""
    from uuid import uuid4

    uid = uuid4().hex[:6]
    phone = f"0917{uid[:7]}"
    if len(phone) < 11:
        phone = f"{phone}00000"[:11]
    nat_id = f"NAT-PH-{uid}"

    # 1. Borrower submits registration
    reg_payload = {
        "firstName": "Maria",
        "lastName": "Santos",
        "phoneNumber": phone,
        "address": "123 Main Street, Manila",
        "dateOfBirth": "1992-05-15",
        "nationalId": nat_id,
        "pinOrPassword": "123456Password!",
    }
    resp = await client.post("/api/v1/client/auth/register", json=reg_payload)
    assert resp.status_code == 201, f"Registration failed: {resp.text}"
    reg_data = resp.json()
    assert reg_data["status"] == "pending"
    registration_id = reg_data["id"]

    # 2. Owner lists registrations and approves applicant
    headers = {"Authorization": f"Bearer {owner_token}"}
    resp = await client.get("/api/v1/borrowers/registrations?status=pending", headers=headers)
    assert resp.status_code == 200
    items = resp.json()
    assert any(i["id"] == registration_id for i in items)

    resp = await client.post(
        f"/api/v1/borrowers/registrations/{registration_id}/approve",
        headers=headers,
    )
    assert resp.status_code == 200
    approve_data = resp.json()
    activation_code = approve_data["activationCode"]
    assert len(activation_code) == 6

    # 3. Borrower redeems activation code
    act_payload = {
        "phoneNumber": phone,
        "activationCode": activation_code,
        "deviceIdentifier": f"test_android_device_{uid}",
    }
    resp = await client.post("/api/v1/client/auth/activate", json=act_payload)
    assert resp.status_code == 200
    token_data = resp.json()
    assert token_data["accountStatus"] == "activated"
    borrower_access_token = token_data["accessToken"]

    # 4. Borrower PIN Login succeeds
    login_payload = {
        "phoneNumber": phone,
        "pinOrPassword": "123456Password!",
        "deviceIdentifier": f"test_android_device_{uid}",
    }
    resp = await client.post("/api/v1/client/auth/login", json=login_payload)
    assert resp.status_code == 200

    # 5. Borrower submits a loan request
    b_headers = {"Authorization": f"Bearer {borrower_access_token}"}
    loan_req_payload = {
        "requestedAmount": "15000.00",
        "requestedTermMonths": 6,
        "purpose": "Business inventory purchase",
    }
    resp = await client.post(
        "/api/v1/client/loan-requests",
        json=loan_req_payload,
        headers=b_headers,
    )
    assert resp.status_code == 201
    loan_req_data = resp.json()
    assert loan_req_data["status"] == "submitted"
    assert loan_req_data["requestedAmount"] == "15000.00"
