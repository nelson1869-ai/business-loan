"""Comprehensive unit and integration tests for borrower portal security boundaries and client endpoints."""

import unittest
from datetime import datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

from httpx import ASGITransport, AsyncClient

from app.core.database import get_db
from app.features.auth.service import create_token
from app.features.borrower_portal.service import (
    create_borrower_access_token,
    normalize_ph_phone_number,
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


class TestBorrowerPortalRouter(unittest.IsolatedAsyncioTestCase):
    """Router and dependency isolation tests for /api/v1/client endpoints."""

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
