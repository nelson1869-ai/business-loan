"""Comprehensive unit and integration tests for borrower portal security boundaries and client endpoints."""

import unittest
from datetime import datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

from httpx import ASGITransport, AsyncClient

from app.core.config import Settings
from app.core.database import get_db
from app.features.auth.service import create_token
from app.features.borrower_portal.service import (
    LOCAL_DEVELOPMENT_OTP,
    create_borrower_access_token,
    dev_otp_provider,
    hash_secret,
    normalize_ph_phone_number,
    request_otp,
    verify_borrower_access_token,
)
from app.features.borrowers.models import Borrower
from app.features.users.models import User
from app.main import app


class TestPhoneNormalization(unittest.TestCase):
    """Test suite for Philippine mobile phone number canonicalization."""

    def test_normalizes_standard_local_format(self) -> None:
        self.assertEqual(normalize_ph_phone_number("09171234567"), "+639171234567")

    def test_normalizes_international_plus_format(self) -> None:
        self.assertEqual(normalize_ph_phone_number("+639171234567"), "+639171234567")

    def test_normalizes_international_no_plus(self) -> None:
        self.assertEqual(normalize_ph_phone_number("639171234567"), "+639171234567")

    def test_normalizes_spaces_dashes_parentheses(self) -> None:
        self.assertEqual(
            normalize_ph_phone_number("+63 (917) 123-4567"), "+639171234567"
        )

    def test_rejects_malformed_numbers(self) -> None:
        with self.assertRaisesRegex(ValueError, "Invalid Philippine mobile number"):
            normalize_ph_phone_number("12345")


class TestBorrowerTokenSecurity(unittest.TestCase):
    """Test token audience separation and claim verification."""

    def test_borrower_token_contains_audience_boundary(self) -> None:
        account = SimpleNamespace(id="acct-1", borrower_id="bor-1")
        token = create_borrower_access_token(account)
        payload = verify_borrower_access_token(token)

        self.assertEqual(payload["aud"], "borrower-app")
        self.assertEqual(payload["account_type"], "borrower")
        self.assertEqual(payload["borrower_account_id"], "acct-1")
        self.assertEqual(payload["borrower_id"], "bor-1")

    def test_officer_token_rejected_by_borrower_verifier(self) -> None:
        officer = SimpleNamespace(id="usr-1", username="officer_user", role="officer")
        officer_token = create_token(officer, "access")

        from app.features.auth.service import TokenValidationError

        with self.assertRaises(TokenValidationError):
            verify_borrower_access_token(officer_token)


class TestLocalDevelopmentOTP(unittest.IsolatedAsyncioTestCase):
    """Verify the fixed local OTP remains opt-in and hashed at rest."""

    async def test_fixed_local_otp_is_hashed_before_storage(self) -> None:
        db = AsyncMock()
        db.add = MagicMock()
        result = MagicMock()
        result.scalar_one_or_none.return_value = None
        db.execute.return_value = result
        settings = Settings(
            app_env="development",
            database_url="postgresql+asyncpg://user:pass@localhost:5432/db",
            jwt_secret_key="strong-random-value-0123456789-ABCDEFGHIJ",
            cors_origins="*",
            local_borrower_otp_enabled=True,
        )

        phone = "+639171234567"
        dev_otp_provider.last_delivered_otp.pop(phone, None)
        try:
            accepted, cooldown = await request_otp(db, phone, settings=settings)

            self.assertTrue(accepted)
            self.assertEqual(cooldown, 60)
            stored_otp = db.add.call_args.args[0]
            self.assertEqual(stored_otp.otp_code_hash, hash_secret(LOCAL_DEVELOPMENT_OTP))
            self.assertNotEqual(stored_otp.otp_code_hash, LOCAL_DEVELOPMENT_OTP)
            self.assertEqual(
                dev_otp_provider.last_delivered_otp[phone], LOCAL_DEVELOPMENT_OTP
            )
            db.flush.assert_awaited_once()
        finally:
            dev_otp_provider.last_delivered_otp.pop(phone, None)


class TestBorrowerPortalRouter(unittest.IsolatedAsyncioTestCase):
    """Router and dependency isolation tests for /api/v1/client endpoints."""

    async def test_request_otp_returns_generic_response(self) -> None:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            res = await client.post(
                "/api/v1/client/auth/request-otp",
                json={"phoneNumber": "09171234567"},
            )
            self.assertEqual(res.status_code, 200)
            data = res.json()
            self.assertIn("If the phone number is eligible", data["message"])
            self.assertGreater(data["resendCooldownSeconds"], 0)
            self.assertLessEqual(data["resendCooldownSeconds"], 60)

    @patch("app.core.database.get_db")
    async def test_officer_client_invitation_issuance(self, mock_get_db) -> None:
        officer = User(
            id="usr-officer-1",
            username="officer_juan",
            hashed_password="pw",
            role="officer",
        )
        borrower = Borrower(
            id="bor-1",
            first_name="Juan",
            last_name="Dela Cruz",
            national_id="PH-123",
            phone="09171234567",
            date_of_birth=datetime(1990, 1, 1).date(),
            status="Active",
        )

        mock_db = AsyncMock()
        mock_db.get.return_value = borrower

        mock_res = MagicMock()
        mock_res.scalar_one_or_none.return_value = officer
        mock_db.execute.return_value = mock_res

        async def _mock_db_gen():
            yield mock_db

        app.dependency_overrides[get_db] = _mock_db_gen
        try:
            officer_token = create_token(officer, "access")
            headers = {"Authorization": f"Bearer {officer_token}"}

            async with AsyncClient(
                transport=ASGITransport(app=app), base_url="http://test"
            ) as client:
                res = await client.post(
                    "/api/v1/borrowers/bor-1/client-invitation",
                    headers=headers,
                    json={"expiresInHours": 24},
                )
                self.assertEqual(res.status_code, 201)
                data = res.json()
                self.assertEqual(data["borrowerId"], "bor-1")
                self.assertEqual(len(data["invitationCode"]), 6)
        finally:
            app.dependency_overrides.pop(get_db, None)

    async def test_officer_token_rejected_by_client_me(self) -> None:
        officer = User(
            id="usr-officer-1",
            username="officer_juan",
            hashed_password="pw",
            role="officer",
        )
        officer_token = create_token(officer, "access")

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            res = await client.get(
                "/api/v1/client/me",
                headers={"Authorization": f"Bearer {officer_token}"},
            )
            self.assertEqual(res.status_code, 401)

    async def test_borrower_token_rejected_by_officer_loans(self) -> None:
        account = SimpleNamespace(id="acct-1", borrower_id="bor-1")
        borrower_token = create_borrower_access_token(account)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            res = await client.get(
                "/api/v1/loans",
                headers={"Authorization": f"Bearer {borrower_token}"},
            )
            self.assertEqual(res.status_code, 401)


if __name__ == "__main__":
    unittest.main()
