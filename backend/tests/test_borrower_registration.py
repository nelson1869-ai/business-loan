"""Security-focused tests for borrower self-registration contracts."""

import unittest
from datetime import date
from types import SimpleNamespace

from pydantic import ValidationError

from app.core.authorization import has_permission
from app.features.borrower_portal.registration_schemas import (
    RegistrationCreate,
    RegistrationCreateAndApproval,
    RegistrationStatusRequest,
)
from app.features.borrower_portal.registration_service import (
    mask_national_id,
    mask_phone,
)
from app.features.borrower_portal.service import hash_secret


class TestRegistrationPublicSchema(unittest.TestCase):
    def payload(self) -> dict:
        return {
            "firstName": "Maria",
            "lastName": "Santos",
            "nationalId": "TEST-2026-0001",
            "phoneNumber": "09171234567",
            "address": "123 Main Street, Bacolod City",
            "dateOfBirth": "1990-04-12",
            "email": "maria@example.com",
            "privacyAccepted": True,
            "termsAccepted": True,
        }

    def test_accepts_and_normalizes_registration(self) -> None:
        value = RegistrationCreate.model_validate(self.payload())
        self.assertEqual(value.phone_number, "+639171234567")
        self.assertEqual(value.date_of_birth, date(1990, 4, 12))
        self.assertEqual(value.national_id, "TEST-2026-0001")
        self.assertEqual(value.address, "123 Main Street, Bacolod City")

    def test_rejects_empty_or_whitespace_address(self) -> None:
        for empty_val in ("", "   "):
            payload = self.payload() | {"address": empty_val}
            with self.subTest(val=empty_val), self.assertRaises(ValidationError):
                RegistrationCreate.model_validate(payload)

    def test_rejects_short_national_id(self) -> None:
        for short_id in ("123", "  12  "):
            payload = self.payload() | {"nationalId": short_id}
            with self.subTest(val=short_id), self.assertRaises(ValidationError):
                RegistrationCreate.model_validate(payload)

    def test_rejects_malformed_mobile_number(self) -> None:
        payload = self.payload() | {"phoneNumber": "123"}
        with self.assertRaises(ValidationError):
            RegistrationCreate.model_validate(payload)

    def test_requires_privacy_and_terms(self) -> None:
        payload = self.payload() | {"privacyAccepted": False}
        with self.assertRaises(ValidationError):
            RegistrationCreate.model_validate(payload)

    def test_rejects_future_birth_date(self) -> None:
        payload = self.payload() | {"dateOfBirth": "2999-01-01"}
        with self.assertRaises(ValidationError):
            RegistrationCreate.model_validate(payload)

    def test_forbids_identity_and_role_mass_assignment(self) -> None:
        for field in (
            "borrowerId",
            "borrowerAccountId",
            "loanId",
            "officerId",
            "adminRole",
            "status",
            "pinOrPassword",
            "extraUnallowedField",
        ):
            with self.subTest(field=field), self.assertRaises(ValidationError):
                RegistrationCreate.model_validate(self.payload() | {field: "attacker"})

    def test_status_requires_an_opaque_token(self) -> None:
        with self.assertRaises(ValidationError):
            RegistrationStatusRequest.model_validate({"registrationToken": "short"})

    def test_create_and_approve_accepts_only_staff_supplied_national_id(self) -> None:
        value = RegistrationCreateAndApproval.model_validate(
            {"nationalId": "TEST-2026-0001"}
        )
        self.assertEqual(value.national_id, "TEST-2026-0001")
        with self.assertRaises(ValidationError):
            RegistrationCreateAndApproval.model_validate(
                {
                    "nationalId": "TEST-2026-0001",
                    "borrowerId": "attacker-controlled",
                }
            )


class TestRegistrationSecurityHelpers(unittest.TestCase):
    def test_token_hash_does_not_persist_raw_token(self) -> None:
        raw = "opaque-registration-token-with-sufficient-entropy"
        self.assertNotEqual(hash_secret(raw), raw)
        self.assertEqual(len(hash_secret(raw)), 64)

    def test_phone_masking(self) -> None:
        masked = mask_phone("+639171234567")
        self.assertNotIn("9171234567", masked)
        self.assertTrue(masked.endswith("567"))

    def test_national_id_masking(self) -> None:
        masked = mask_national_id("TEST-2026-0001")
        self.assertNotIn("TEST-2026", masked)
        self.assertTrue(masked.endswith("0001"))

    def test_review_permission_excludes_officer(self) -> None:
        self.assertFalse(
            has_permission(
                SimpleNamespace(role="officer"), "borrower_registration.review"
            )
        )
        self.assertTrue(
            has_permission(
                SimpleNamespace(role="manager"), "borrower_registration.review"
            )
        )
        self.assertTrue(
            has_permission(
                SimpleNamespace(role="admin"), "borrower_registration.review"
            )
        )


class TestRegistrationServiceAndApiPersistence(unittest.IsolatedAsyncioTestCase):
    """Integration test suite proving atomic database persistence for registration requests and audits."""

    async def test_submit_registration_service_persists_request_and_audit(self) -> None:
        from unittest.mock import AsyncMock
        from app.features.borrower_portal import registration_service
        from app.features.borrower_portal.models import (
            BorrowerRegistrationAudit,
            BorrowerRegistrationRequest,
        )
        from app.features.borrower_portal.registration_schemas import RegistrationCreate

        payload = RegistrationCreate.model_validate(
            {
                "firstName": "Nelson",
                "lastName": "Fernandez",
                "nationalId": "145865858",
                "address": "Bacolod City",
                "phoneNumber": "09916084400",
                "dateOfBirth": "1990-01-01",
                "privacyAccepted": True,
                "termsAccepted": True,
            }
        )

        db = AsyncMock()
        db.scalar.return_value = None

        request, token = await registration_service.submit(db, payload)

        self.assertIsNotNone(token)
        self.assertTrue(len(token) > 20)
        self.assertNotEqual(request.status_token_hash, token)
        self.assertEqual(request.first_name, "Nelson")
        self.assertEqual(request.last_name, "Fernandez")
        self.assertEqual(request.address, "Bacolod City")
        self.assertEqual(request.status, "pending")

        # Verify db.add was called for both BorrowerRegistrationRequest and BorrowerRegistrationAudit
        self.assertEqual(db.add.call_count, 2)
        added_request = db.add.call_args_list[0][0][0]
        added_audit = db.add.call_args_list[1][0][0]

        self.assertIsInstance(added_request, BorrowerRegistrationRequest)
        self.assertIsInstance(added_audit, BorrowerRegistrationAudit)
        self.assertEqual(added_audit.action, "REGISTRATION_SUBMITTED")
        self.assertEqual(added_audit.target_type, "registration_request")
        self.assertEqual(added_audit.target_id, request.id)
        db.flush.assert_awaited_once()

    async def test_register_api_endpoint_end_to_end(self) -> None:
        from unittest.mock import AsyncMock
        from httpx import ASGITransport, AsyncClient
        from app.core.database import get_db
        from app.features.borrower_portal.models import (
            BorrowerRegistrationAudit,
            BorrowerRegistrationRequest,
        )
        from app.main import app

        mock_db = AsyncMock()
        mock_db.scalar.return_value = None

        async def _override_get_db():
            yield mock_db

        app.dependency_overrides[get_db] = _override_get_db
        try:
            async with AsyncClient(
                transport=ASGITransport(app=app), base_url="http://testserver"
            ) as client:
                res = await client.post(
                    "/api/v1/client/auth/register",
                    json={
                        "firstName": "Nelson",
                        "lastName": "Fernandez",
                        "nationalId": "145865858",
                        "address": "Bacolod City",
                        "phoneNumber": "09916084400",
                        "dateOfBirth": "1990-01-01",
                        "privacyAccepted": True,
                        "termsAccepted": True,
                    },
                )
                self.assertEqual(res.status_code, 201, res.text)
                body = res.json()
                self.assertIn("requestId", body)
                self.assertIn("registrationToken", body)
                self.assertEqual(body["status"], "pending")

                # Verify mock_db received added request and audit
                self.assertEqual(mock_db.add.call_count, 2)
                added_request = mock_db.add.call_args_list[0][0][0]
                added_audit = mock_db.add.call_args_list[1][0][0]

                self.assertIsInstance(added_request, BorrowerRegistrationRequest)
                self.assertIsInstance(added_audit, BorrowerRegistrationAudit)
                self.assertEqual(added_request.address, "Bacolod City")
                self.assertEqual(added_audit.action, "REGISTRATION_SUBMITTED")
                self.assertEqual(added_audit.target_type, "registration_request")
                mock_db.commit.assert_awaited_once()
        finally:
            app.dependency_overrides.pop(get_db, None)
