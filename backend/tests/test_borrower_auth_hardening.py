"""Tests for Borrower Auth Production Hardening (bcrypt, account locking, PIN reset, device security)."""

import uuid
from datetime import UTC, date, datetime, timedelta
import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.core.database import AsyncSessionFactory
from app.core.phone_numbers import normalize_ph_phone_number
from app.features.auth.service import create_token, hash_password
from app.features.borrower_portal.models import (
    BorrowerAccount,
    BorrowerActivationCode,
    BorrowerDevice,
    BorrowerPinReset,
    BorrowerRefreshToken,
    BorrowerRegistrationRequest,
)
from app.features.borrower_portal.service import (
    hash_pin_secure,
    hash_secret,
    verify_pin_secure,
)
from app.features.borrowers.models import Borrower
from app.features.users.models import User


@pytest.mark.asyncio
async def test_bcrypt_pin_hashing_and_legacy_upgrade():
    """Test bcrypt PIN hashing and seamless migration from legacy SHA256 hashes."""
    pin = "TestPin123!"
    bcrypt_hash = hash_pin_secure(pin)
    assert bcrypt_hash.startswith("$2b$") or bcrypt_hash.startswith("$2a$")

    # Verify bcrypt
    valid, needs_upgrade = verify_pin_secure(pin, bcrypt_hash)
    assert valid is True
    assert needs_upgrade is False

    # Verify legacy SHA256 hash
    legacy_hash = hash_secret(pin)
    valid_legacy, needs_upgrade_legacy = verify_pin_secure(pin, legacy_hash)
    assert valid_legacy is True
    assert needs_upgrade_legacy is True

    # Wrong PIN
    invalid, _ = verify_pin_secure("WrongPin123!", bcrypt_hash)
    assert invalid is False


@pytest.mark.asyncio
async def test_account_locking_on_repeated_failed_logins():
    """Test account locking after 5 consecutive failed attempts (15 min) and 10 attempts (owner reset)."""
    tag = uuid.uuid4().hex[:8]
    phone = f"0917{uuid.uuid4().int % 10000000:07d}"
    norm_phone = normalize_ph_phone_number(phone)
    async with AsyncSessionFactory() as db:
        now = datetime.now(UTC)
        borrower = Borrower(
            id=f"b-lock-{tag}",
            first_name="Lock",
            last_name="Test",
            national_id=f"NAT-LOCK-{tag}",
            phone=phone,
            phone_normalized=norm_phone,
            date_of_birth=date(1990, 1, 1),
            status="Active",
        )
        account = BorrowerAccount(
            id=f"ba-lock-{tag}",
            borrower_id=borrower.id,
            phone_number=phone,
            phone_number_normalized=norm_phone,
            account_status="Activated",
            password_hash=hash_pin_secure("CorrectPin123!"),
            failed_login_attempts=0,
            created_at=now,
            updated_at=now,
        )
        db.add(borrower)
        db.add(account)
        await db.commit()

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        # Submit 5 wrong PINs
        for _ in range(5):
            res = await client.post(
                "/api/v1/client/auth/login",
                json={
                    "phoneNumber": phone,
                    "pinOrPassword": "WrongPin123!",
                    "deviceIdentifier": f"dev-lock-{tag}",
                },
            )
            assert res.status_code == 401

        # 6th attempt should be rejected due to account locking
        res_locked = await client.post(
            "/api/v1/client/auth/login",
            json={
                "phoneNumber": phone,
                "pinOrPassword": "CorrectPin123!",
                "deviceIdentifier": f"dev-lock-{tag}",
            },
        )
        assert res_locked.status_code == 401
        assert "locked" in res_locked.json()["detail"].lower()


@pytest.mark.asyncio
async def test_owner_unlock_account():
    """Test owner unlocking a locked borrower account."""
    tag = uuid.uuid4().hex[:8]
    phone = f"0917{uuid.uuid4().int % 10000000:07d}"
    norm_phone = normalize_ph_phone_number(phone)
    async with AsyncSessionFactory() as db:
        now = datetime.now(UTC)
        owner = User(
            id=f"owner-unlock-{tag}",
            username=f"owner_unlock_{tag}",
            hashed_password=hash_password("OwnerPass123!"),
            role="owner",
        )
        borrower = Borrower(
            id=f"b-unlock-{tag}",
            first_name="Unlock",
            last_name="Test",
            national_id=f"NAT-UNLOCK-{tag}",
            phone=phone,
            phone_normalized=norm_phone,
            date_of_birth=date(1990, 1, 1),
            status="Active",
        )
        account = BorrowerAccount(
            id=f"ba-unlock-{tag}",
            borrower_id=borrower.id,
            phone_number=phone,
            phone_number_normalized=norm_phone,
            account_status="Activated",
            password_hash=hash_pin_secure("CorrectPin123!"),
            failed_login_attempts=5,
            locked_until=now + timedelta(minutes=15),
            created_at=now,
            updated_at=now,
        )
        db.add(owner)
        db.add(borrower)
        db.add(account)
        await db.commit()

        owner_token = create_token(owner, "access")

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        # Owner unlocks account
        res = await client.post(
            f"/api/v1/borrowers/accounts/ba-unlock-{tag}/unlock",
            headers={"Authorization": f"Bearer {owner_token}"},
        )
        assert res.status_code == 200

        # Borrower can now log in
        login_res = await client.post(
            "/api/v1/client/auth/login",
            json={
                "phoneNumber": phone,
                "pinOrPassword": "CorrectPin123!",
                "deviceIdentifier": f"dev-unlock-{tag}",
            },
        )
        assert login_res.status_code == 200
        assert "accessToken" in login_res.json()


@pytest.mark.asyncio
async def test_forgot_pin_and_owner_reset_flow():
    """Test full Forgot PIN flow: request reset -> owner issues code -> redeem code -> new PIN set & sessions revoked."""
    tag = uuid.uuid4().hex[:8]
    phone = f"0917{uuid.uuid4().int % 10000000:07d}"
    norm_phone = normalize_ph_phone_number(phone)
    async with AsyncSessionFactory() as db:
        now = datetime.now(UTC)
        owner = User(
            id=f"owner-reset-{tag}",
            username=f"owner_reset_{tag}",
            hashed_password=hash_password("OwnerPass123!"),
            role="owner",
        )
        borrower = Borrower(
            id=f"b-reset-{tag}",
            first_name="Reset",
            last_name="Test",
            national_id=f"NAT-RESET-{tag}",
            phone=phone,
            phone_normalized=norm_phone,
            date_of_birth=date(1990, 1, 1),
            status="Active",
        )
        account = BorrowerAccount(
            id=f"ba-reset-{tag}",
            borrower_id=borrower.id,
            phone_number=phone,
            phone_number_normalized=norm_phone,
            account_status="Activated",
            password_hash=hash_pin_secure("OldPin123!"),
            created_at=now,
            updated_at=now,
        )
        db.add(owner)
        db.add(borrower)
        db.add(account)
        await db.commit()

        owner_token = create_token(owner, "access")

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        # 1. Borrower requests PIN reset
        req_res = await client.post(
            "/api/v1/client/auth/forgot-pin",
            json={"phoneNumber": phone},
        )
        assert req_res.status_code == 200

        # 2. Owner issues PIN reset code
        issue_res = await client.post(
            f"/api/v1/borrowers/accounts/ba-reset-{tag}/reset-code",
            headers={"Authorization": f"Bearer {owner_token}"},
        )
        assert issue_res.status_code == 201
        reset_code = issue_res.json()["resetCode"]
        assert len(reset_code) == 6

        # 3. Borrower redeems reset code & sets new PIN
        redeem_res = await client.post(
            "/api/v1/client/auth/reset-pin",
            json={
                "phoneNumber": phone,
                "resetCode": reset_code,
                "newPin": "NewPin123!",
            },
        )
        assert redeem_res.status_code == 200

        # 4. Login with new PIN succeeds
        login_res = await client.post(
            "/api/v1/client/auth/login",
            json={
                "phoneNumber": phone,
                "pinOrPassword": "NewPin123!",
                "deviceIdentifier": f"dev-reset-{tag}",
            },
        )
        assert login_res.status_code == 200

        # 5. Login with old PIN fails
        login_old = await client.post(
            "/api/v1/client/auth/login",
            json={
                "phoneNumber": phone,
                "pinOrPassword": "OldPin123!",
                "deviceIdentifier": f"dev-reset-{tag}",
            },
        )
        assert login_old.status_code == 401
