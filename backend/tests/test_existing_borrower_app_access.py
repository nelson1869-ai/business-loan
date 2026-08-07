from datetime import UTC, date, datetime
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import ASGITransport, AsyncClient

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.features.auth.service import verify_password
from app.features.borrower_portal.models import (
    BorrowerAccount,
    BorrowerActivationCode,
)
from app.features.borrower_portal.schemas import BorrowerActivationRequest
from app.features.borrower_portal.service import (
    enable_existing_borrower_app_access,
    get_borrower_app_access_status,
    hash_secret,
    verify_activation_code_and_activate,
)
from app.features.borrowers.models import Borrower
from app.features.loans.models import Loan
from app.features.users.models import User
from app.main import app


@pytest.fixture
def owner_user() -> User:
    return User(
        id="owner-100",
        username="owner",
        role="owner",
        hashed_password="dummy",
    )


@pytest.fixture
def officer_user() -> User:
    return User(
        id="officer-100",
        username="officer",
        role="officer",
        hashed_password="dummy",
    )


@pytest.fixture
def existing_borrower() -> Borrower:
    return Borrower(
        id="bor-existing-100",
        first_name="Juan",
        last_name="Dela Cruz",
        national_id="NID-123456",
        phone="09171234567",
        phone_normalized="09171234567",
        date_of_birth=date(1990, 5, 15),
        status="Active",
    )


@pytest.fixture
def existing_loan(existing_borrower: Borrower) -> Loan:
    return Loan(
        id="loan-existing-100",
        borrower_id=existing_borrower.id,
        principal_amount=Decimal("10000.00"),
        outstanding_principal=Decimal("8000.00"),
        status="Active",
        loan_policy_id="pol-100",
        created_at=datetime.now(UTC),
    )


@pytest.mark.asyncio
async def test_enable_existing_borrower_app_access_success(
    owner_user: User, existing_borrower: Borrower
) -> None:
    db = AsyncMock()
    db.flush = AsyncMock()
    db.add = MagicMock()
    # 1. Borrower query, 2. No BorrowerAccount, 3. No phone conflict
    db.scalar.side_effect = [existing_borrower, None, None]
    
    # generate_new_activation_code queries BorrowerAccount via db.execute
    mock_acct_res = MagicMock()
    mock_acct_res.scalar_one_or_none.return_value = BorrowerAccount(
        id="acct-new",
        borrower_id=existing_borrower.id,
        phone_number="09171234567",
        phone_number_normalized="09171234567",
        account_status="approved",
    )
    mock_update_res = MagicMock()
    db.execute.side_effect = [mock_acct_res, mock_update_res]

    res = await enable_existing_borrower_app_access(db, existing_borrower.id, owner_user)

    assert res.borrower_id == existing_borrower.id
    assert res.account_status == "approved"
    assert len(res.activation_code) == 6
    assert res.activation_code.isdigit()
    assert res.expires_at > datetime.now(UTC)


@pytest.mark.asyncio
async def test_enable_access_duplicate_prevented(
    owner_user: User, existing_borrower: Borrower
) -> None:
    db = AsyncMock()
    existing_acct = BorrowerAccount(
        id="acct-100",
        borrower_id=existing_borrower.id,
        phone_number="09171234567",
        phone_number_normalized="09171234567",
        account_status="approved",
    )
    db.scalar.side_effect = [existing_borrower, existing_acct]

    with pytest.raises(ValueError, match="already enabled"):
        await enable_existing_borrower_app_access(db, existing_borrower.id, owner_user)


@pytest.mark.asyncio
async def test_enable_access_phone_conflict_rejected(
    owner_user: User, existing_borrower: Borrower
) -> None:
    db = AsyncMock()
    other_acct = BorrowerAccount(
        id="acct-other",
        borrower_id="bor-other",
        phone_number="09171234567",
        phone_number_normalized="09171234567",
        account_status="activated",
    )
    db.scalar.side_effect = [existing_borrower, None, other_acct]

    with pytest.raises(ValueError, match="Phone number is already linked"):
        await enable_existing_borrower_app_access(db, existing_borrower.id, owner_user)


@pytest.mark.asyncio
async def test_status_endpoint_never_returns_raw_activation_code(
    existing_borrower: Borrower,
) -> None:
    db = AsyncMock()
    existing_acct = BorrowerAccount(
        id="acct-100",
        borrower_id=existing_borrower.id,
        phone_number="09171234567",
        phone_number_normalized="09171234567",
        account_status="approved",
    )
    active_code = BorrowerActivationCode(
        id="code-100",
        borrower_id=existing_borrower.id,
        borrower_account_id=existing_acct.id,
        code_hash=hash_secret("123456"),
        expires_at=datetime(2028, 1, 1, tzinfo=UTC),
        used_at=None,
    )
    db.scalar.side_effect = [existing_borrower, existing_acct]
    mock_code_res = MagicMock()
    mock_code_res.scalar_one_or_none.return_value = active_code
    mock_count_res = MagicMock()
    mock_count_res.scalar_one.return_value = 1
    db.execute.side_effect = [mock_code_res, mock_count_res]

    status_resp = await get_borrower_app_access_status(db, existing_borrower.id)

    assert status_resp.has_account is True
    assert status_resp.account_status == "approved"
    assert status_resp.activation_pending is True
    assert not hasattr(status_resp, "activation_code")


@pytest.mark.asyncio
async def test_activation_requires_pin_creation_and_mismatch_rejected(
    existing_borrower: Borrower,
) -> None:
    db = AsyncMock()
    db.flush = AsyncMock()
    db.add = MagicMock()
    acct_no_pin = BorrowerAccount(
        id="acct-100",
        borrower_id=existing_borrower.id,
        phone_number="09171234567",
        phone_number_normalized="09171234567",
        account_status="approved",
        password_hash=None,
    )
    code_rec = BorrowerActivationCode(
        id="code-100",
        borrower_id=existing_borrower.id,
        borrower_account_id=acct_no_pin.id,
        code_hash=hash_secret("123456"),
        expires_at=datetime(2028, 1, 1, tzinfo=UTC),
        attempts=0,
        max_attempts=5,
        used_at=None,
    )

    db.execute.side_effect = [
        MagicMock(scalar_one_or_none=lambda: acct_no_pin),
        MagicMock(scalar_one_or_none=lambda: code_rec),
    ]

    req_missing_pin = BorrowerActivationRequest(
        phoneNumber="09171234567",
        activationCode="123456",
        deviceIdentifier="device-abc",
    )
    with pytest.raises(ValueError, match="PIN creation is required"):
        await verify_activation_code_and_activate(db, req_missing_pin)

    db.execute.side_effect = [
        MagicMock(scalar_one_or_none=lambda: acct_no_pin),
        MagicMock(scalar_one_or_none=lambda: code_rec),
    ]
    req_mismatch = BorrowerActivationRequest(
        phoneNumber="09171234567",
        activationCode="123456",
        deviceIdentifier="device-abc",
        newPin="1234",
        confirmPin="5678",
    )
    with pytest.raises(ValueError, match="do not match"):
        await verify_activation_code_and_activate(db, req_mismatch)


@pytest.mark.asyncio
async def test_activation_success_hashes_pin_and_trusts_device(
    existing_borrower: Borrower,
) -> None:
    db = AsyncMock()
    db.flush = AsyncMock()
    db.add = MagicMock()
    acct_no_pin = BorrowerAccount(
        id="acct-100",
        borrower_id=existing_borrower.id,
        phone_number="09171234567",
        phone_number_normalized="09171234567",
        account_status="approved",
        password_hash=None,
    )
    code_rec = BorrowerActivationCode(
        id="code-100",
        borrower_id=existing_borrower.id,
        borrower_account_id=acct_no_pin.id,
        code_hash=hash_secret("123456"),
        expires_at=datetime(2028, 1, 1, tzinfo=UTC),
        attempts=0,
        max_attempts=5,
        used_at=None,
    )

    mock_acct_res = MagicMock()
    mock_acct_res.scalar_one_or_none.return_value = acct_no_pin
    mock_code_res = MagicMock()
    mock_code_res.scalar_one_or_none.return_value = code_rec
    mock_empty_res = MagicMock()
    mock_empty_res.scalar_one_or_none.return_value = None

    db.execute.side_effect = lambda stmt, *a, **kw: (
        mock_acct_res if "borrower_accounts" in str(stmt)
        else mock_code_res if "borrower_activation_codes" in str(stmt)
        else mock_empty_res
    )

    req_valid = BorrowerActivationRequest(
        phoneNumber="09171234567",
        activationCode="123456",
        deviceIdentifier="device-abc",
        newPin="1234",
        confirmPin="1234",
    )

    acct, access_token, refresh_token, _ = await verify_activation_code_and_activate(
        db, req_valid
    )

    assert acct.account_status == "activated"
    assert acct.password_hash is not None
    assert verify_password("1234", acct.password_hash) is True
    assert access_token is not None
    assert refresh_token is not None


@pytest.mark.asyncio
async def test_owner_endpoint_enable_access_requires_owner(
    owner_user: User, officer_user: User
) -> None:
    async def mock_endpoint_db():
        session = AsyncMock()
        mock_res = MagicMock()
        mock_res.scalar_one_or_none.return_value = None
        session.scalar.return_value = None
        session.execute.return_value = mock_res
        yield session

    app.dependency_overrides[get_db] = mock_endpoint_db
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        # Officer -> 403 Forbidden
        app.dependency_overrides[get_current_user] = lambda: officer_user
        resp_officer = await client.post("/api/v1/borrowers/bor-100/enable-app-access")
        assert resp_officer.status_code == 403

        # Owner -> Proceeds (returns 404 for non-existent borrower ID)
        app.dependency_overrides[get_current_user] = lambda: owner_user
        resp_owner = await client.post("/api/v1/borrowers/bor-nonexistent/enable-app-access")
        assert resp_owner.status_code == 404

    app.dependency_overrides.clear()
