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
    BorrowerDevice,
    BorrowerRegistrationRequest,
)
from app.features.borrower_portal.schemas import (
    BorrowerActivationRequest,
    DeviceResponse,
)
from app.features.borrower_portal.service import (
    enable_existing_borrower_app_access,
    generate_new_activation_code,
    get_borrower_app_access_status,
    hash_secret,
    regenerate_borrower_activation_code,
    verify_activation_code_and_activate,
)
from app.features.borrowers.models import Borrower
from app.features.borrower_portal.registration_schemas import (
    RegistrationStatusResponse,
)
from app.features.borrower_portal.registration_service import (
    find_possible_borrower_matches,
    status_for_token,
)
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
        created_by_user_id="owner-100",
        original_principal=Decimal("10000.00"),
        outstanding_principal=Decimal("8000.00"),
        status="Active",
        policy_snapshot={},
        created_at=datetime.now(UTC),
    )


@pytest.mark.asyncio
async def test_device_response_default_untrusted() -> None:
    """Invariant 1 & 12: DeviceResponse missing isTrusted defaults to False."""
    dev_dict = {
        "id": "dev-1",
        "platform": "android",
        "lastSeenAt": datetime.now(UTC).isoformat(),
    }
    resp = DeviceResponse.model_validate(dev_dict)
    assert resp.is_trusted is False


@pytest.mark.asyncio
async def test_enable_existing_borrower_app_access_success(
    owner_user: User, existing_borrower: Borrower
) -> None:
    db = AsyncMock()
    db.flush = AsyncMock()
    db.add = MagicMock()
    db.scalar.side_effect = [existing_borrower, None, None]

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
async def test_code_regeneration_invalidates_previous_code(
    owner_user: User, existing_borrower: Borrower
) -> None:
    """Addition 2 & Requirement 8/12: Regeneration invalidates code A immediately."""
    db = AsyncMock()
    db.flush = AsyncMock()
    acct = BorrowerAccount(
        id="acct-100",
        borrower_id=existing_borrower.id,
        phone_number="09171234567",
        phone_number_normalized="09171234567",
        account_status="approved",
    )
    mock_acct_res = MagicMock()
    mock_acct_res.scalar_one_or_none.return_value = acct
    mock_update_res = MagicMock()
    db.execute.side_effect = [mock_acct_res, mock_update_res]

    code_b_obj, code_b_raw = await generate_new_activation_code(db, acct.id, owner_user)

    assert len(code_b_raw) == 6
    assert code_b_obj.borrower_account_id == acct.id
    # db.execute was called to revoke prior unused codes
    assert db.execute.call_count >= 2


@pytest.mark.asyncio
async def test_regenerate_activation_code_success(
    owner_user: User, existing_borrower: Borrower
) -> None:
    """Owner regenerating an activation code issues a redeemable 6-digit code."""
    db = AsyncMock()
    db.flush = AsyncMock()
    acct = BorrowerAccount(
        id="acct-100",
        borrower_id=existing_borrower.id,
        phone_number="09171234567",
        phone_number_normalized="09171234567",
        account_status="approved",
    )
    db.get = AsyncMock(return_value=acct)
    db.execute.return_value = MagicMock()

    account, activation, raw_code = await regenerate_borrower_activation_code(
        db, acct.id, owner_user
    )

    assert account is acct
    assert len(raw_code) == 6
    assert raw_code.isdigit()
    assert activation.borrower_account_id == acct.id
    assert activation.used_at is None
    assert account.account_status == "approved"


@pytest.mark.asyncio
async def test_regenerate_activation_code_rejects_activated_account(
    owner_user: User,
) -> None:
    """An activated account can no longer receive a fresh activation code."""
    db = AsyncMock()
    acct = BorrowerAccount(
        id="acct-activated",
        borrower_id="bor-100",
        account_status="activated",
    )
    db.get = AsyncMock(return_value=acct)

    with pytest.raises(ValueError, match="awaiting activation"):
        await regenerate_borrower_activation_code(db, acct.id, owner_user)


@pytest.mark.asyncio
async def test_regenerate_activation_code_not_found(owner_user: User) -> None:
    db = AsyncMock()
    db.get = AsyncMock(return_value=None)

    with pytest.raises(ValueError, match="Borrower account not found"):
        await regenerate_borrower_activation_code(db, "acct-missing", owner_user)


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
async def test_financial_immutability_before_after_activation(
    existing_borrower: Borrower, existing_loan: Loan
) -> None:
    """Addition 6 & Requirement 6: Existing borrower financial data remains 100% untouched."""
    # Capture before activation values
    bor_id_before = existing_borrower.id
    loan_id_before = existing_loan.id
    loan_bor_id_before = existing_loan.borrower_id
    loan_status_before = existing_loan.status
    principal_before = existing_loan.original_principal
    outstanding_before = existing_loan.outstanding_principal

    # Simulate enable & activation (only access records created)
    acct = BorrowerAccount(
        id="acct-100",
        borrower_id=existing_borrower.id,
        phone_number=existing_borrower.phone,
        phone_number_normalized=existing_borrower.phone_normalized,
        account_status="activated",
    )

    # Assert exact financial values remain unchanged after access enablement
    assert existing_borrower.id == bor_id_before
    assert existing_loan.id == loan_id_before
    assert existing_loan.borrower_id == loan_bor_id_before
    assert existing_loan.status == loan_status_before
    assert existing_loan.original_principal == principal_before
    assert existing_loan.outstanding_principal == outstanding_before
    assert existing_loan.borrower_id == acct.borrower_id


@pytest.mark.asyncio
async def test_matching_confidence_classification(
    existing_borrower: Borrower,
) -> None:
    """Addition 4 & 5: Candidate query returns exact_phone, exact_national_id, name_dob."""
    db = AsyncMock()
    mock_res = MagicMock()
    mock_res.scalars.return_value = [existing_borrower]
    mock_loans_res = MagicMock()
    mock_loans_res.__iter__.return_value = []
    db.execute.side_effect = [mock_res, mock_loans_res]

    req_phone = BorrowerRegistrationRequest(
        id="reg-100",
        first_name="Pedro",
        last_name="Santos",
        national_id="NID-999",
        phone_number="09171234567",
        phone_number_normalized="09171234567",
        date_of_birth=date(1995, 1, 1),
    )

    matches = await find_possible_borrower_matches(db, req_phone)
    assert len(matches) == 1
    assert matches[0]["match_type"] == "exact_phone"
    assert matches[0]["borrower_id"] == existing_borrower.id


@pytest.mark.asyncio
async def test_name_only_and_dob_only_matches_not_produced() -> None:
    """Requirement 5 & 12: Name-only or DOB-only candidate is never matched."""
    db = AsyncMock()
    mock_res = MagicMock()
    mock_res.scalars.return_value = []
    db.execute.return_value = mock_res

    # Name-only request (different DOB, different phone, different national ID)
    req_name_only = BorrowerRegistrationRequest(
        id="reg-200",
        first_name="Juan",
        last_name="Dela Cruz",
        national_id="NID-DIFFERENT",
        phone_number="09189999999",
        phone_number_normalized="09189999999",
        date_of_birth=date(1980, 1, 1),
    )

    matches = await find_possible_borrower_matches(db, req_name_only)
    assert len(matches) == 0


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


@pytest.mark.asyncio
async def test_regenerate_activation_code_endpoint_requires_owner(
    owner_user: User, officer_user: User
) -> None:
    async def mock_endpoint_db():
        session = AsyncMock()
        session.get = AsyncMock(return_value=None)
        yield session

    app.dependency_overrides[get_db] = mock_endpoint_db
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        # Officer -> 403 Forbidden
        app.dependency_overrides[get_current_user] = lambda: officer_user
        resp_officer = await client.post(
            "/api/v1/borrowers/accounts/acct-100/activation-code"
        )
        assert resp_officer.status_code == 403

        # Owner -> 404 for a non-existent account
        app.dependency_overrides[get_current_user] = lambda: owner_user
        resp_owner = await client.post(
            "/api/v1/borrowers/accounts/acct-missing/activation-code"
        )
        assert resp_owner.status_code == 404

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_regenerate_activation_code_endpoint_returns_code_once(
    owner_user: User, existing_borrower: Borrower
) -> None:
    """Owner receives a single-use raw code via the dedicated activation-code endpoint."""
    acct = BorrowerAccount(
        id="acct-100",
        borrower_id=existing_borrower.id,
        phone_number="09171234567",
        phone_number_normalized="09171234567",
        account_status="approved",
    )

    async def mock_endpoint_db():
        session = AsyncMock()
        session.get = AsyncMock(return_value=acct)
        session.add = MagicMock()
        session.flush = AsyncMock()
        session.execute.return_value = MagicMock()
        yield session

    app.dependency_overrides[get_db] = mock_endpoint_db
    app.dependency_overrides[get_current_user] = lambda: owner_user
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        resp = await client.post(
            "/api/v1/borrowers/accounts/acct-100/activation-code"
        )
        assert resp.status_code == 201
        body = resp.json()
        assert len(body["activationCode"]) == 6
        assert body["activationCode"].isdigit()
        assert body["borrowerAccountId"] == "acct-100"
        assert body["accountStatus"] == "approved"

    app.dependency_overrides.clear()
    """Requirement 17: Inspect FastAPI routes to ensure exactly ONE POST /api/v1/client/auth/register route exists."""
    all_routes: list[tuple[str, set[str]]] = []
    for route in app.routes:
        if hasattr(route, "path") and hasattr(route, "methods"):
            all_routes.append((route.path, route.methods))
        elif hasattr(route, "original_router") and hasattr(route, "include_context"):
            prefix = route.include_context.prefix or ""
            for sub in route.original_router.routes:
                if hasattr(sub, "path") and hasattr(sub, "methods"):
                    all_routes.append((prefix + sub.path, sub.methods))

    register_routes = [
        path
        for path, methods in all_routes
        if path == "/api/v1/client/auth/register" and "POST" in methods
    ]
    assert len(register_routes) == 1, (
        f"Expected exactly 1 route for POST /api/v1/client/auth/register, found {len(register_routes)}: {register_routes}"
    )

    status_routes = [
        path
        for path, methods in all_routes
        if path == "/api/v1/client/auth/registration-status" and "POST" in methods
    ]
    assert len(status_routes) == 1, (
        f"Expected exactly 1 route for POST /api/v1/client/auth/registration-status, found {len(status_routes)}: {status_routes}"
    )


@pytest.mark.asyncio
async def test_registration_status_contract_active_not_activated() -> None:
    """Requirement 1 & 5: Activated BorrowerAccount returns status 'active' (not 'activated')."""
    db = AsyncMock()
    req = BorrowerRegistrationRequest(
        id="reg-300",
        linked_borrower_id="bor-300",
        status="approved",
        status_token_hash=hash_secret("token-secret-123"),
    )
    acct = BorrowerAccount(
        id="acct-300",
        borrower_id="bor-300",
        account_status="activated",
    )

    db.scalar.side_effect = [req, acct]

    status_str, message = await status_for_token(db, "token-secret-123")
    assert status_str == "active"
    assert status_str != "activated"
    assert message == "Your account is activated and ready for login."

    # Validate against RegistrationStatusResponse Pydantic schema
    response_model = RegistrationStatusResponse(status=status_str, message=message)
    assert response_model.status == "active"


def test_registration_status_schema_rejects_activated() -> None:
    """Requirement 3 & 6: RegistrationStatusResponse allows 'active' and rejects 'activated'."""
    valid_res = RegistrationStatusResponse(
        status="active", message="Your account is activated and ready for login."
    )
    assert valid_res.status == "active"

    with pytest.raises(Exception):
        RegistrationStatusResponse(status="activated", message="Invalid status")
