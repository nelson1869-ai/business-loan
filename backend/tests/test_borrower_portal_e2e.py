"""Mocked API lifecycle and router logic unit test suite for borrower portal authentication.

Note: This module tests endpoint handler routing and payload serializations using
an in-memory mocked database session (AsyncMock/MagicMock). For real database
integration tests executing actual SQL queries against real tables, see
test_borrower_portal_db_integration.py.
"""

import unittest
from datetime import datetime
from unittest.mock import AsyncMock, MagicMock

from httpx import ASGITransport, AsyncClient

from app.core.database import get_db
from app.features.auth.service import create_token
from app.features.borrower_portal.models import (
    BorrowerAccount,
    BorrowerDevice,
    BorrowerInvitation,
    BorrowerOTP,
    BorrowerRefreshToken,
)
from app.features.borrower_portal.service import (
    dev_otp_provider,
)
from app.features.borrowers.models import Borrower
from app.features.users.models import User
from app.main import app


class TestBorrowerPortalMockedApiLifecycle(unittest.IsolatedAsyncioTestCase):
    """Mocked API contract and router lifecycle tests for officer invitation, OTP activation,

    token rotation, reuse detection, device management, and boundary isolation.
    """

    async def test_full_borrower_portal_lifecycle(self) -> None:
        # 1. Create officer user
        officer = User(
            id="usr-officer-e2e",
            username="officer_e2e",
            hashed_password="hashed_password_123",
            role="officer",
        )

        # 2. Create borrower
        borrower = Borrower(
            id="bor-e2e-101",
            first_name="Maria",
            last_name="Santos",
            national_id="PH-98765",
            phone="09179876543",
            date_of_birth=datetime(1992, 5, 15).date(),
            status="Active",
        )

        # In-memory mock database store for E2E flow
        db_store: dict[str, dict] = {
            "users": {officer.id: officer},
            "borrowers": {borrower.id: borrower},
            "invitations": {},
            "otps": {},
            "accounts": {},
            "devices": {},
            "refresh_tokens": {},
            "refresh_tokens_by_hash": {},
        }

        mock_db = MagicMock()

        # Mock DB get
        async def mock_get(entity_cls, key):
            if entity_cls == User:
                return db_store["users"].get(key)
            if entity_cls == Borrower:
                return db_store["borrowers"].get(key)
            if entity_cls == BorrowerAccount:
                return db_store["accounts"].get(key)
            return None

        mock_db.get = AsyncMock(side_effect=mock_get)

        # Mock DB add
        def mock_add(instance):
            if isinstance(instance, BorrowerInvitation):
                db_store["invitations"][instance.id] = instance
            elif isinstance(instance, BorrowerOTP):
                db_store["otps"][instance.id] = instance
            elif isinstance(instance, BorrowerAccount):
                db_store["accounts"][instance.id] = instance
            elif isinstance(instance, BorrowerDevice):
                db_store["devices"][instance.id] = instance
            elif isinstance(instance, BorrowerRefreshToken):
                db_store["refresh_tokens"][instance.id] = instance
                db_store["refresh_tokens_by_hash"][instance.token_hash] = instance

        mock_db.add = MagicMock(side_effect=mock_add)

        # Mock DB execute query
        async def mock_execute(stmt):
            stmt_str = str(stmt).lower()
            res = MagicMock()

            # Attempt parameter extraction for exact hash lookup
            params = {}
            try:
                params = stmt.compile().params
            except Exception:
                pass

            if "from borrower_otps" in stmt_str:
                latest_otp = (
                    list(db_store["otps"].values())[-1] if db_store["otps"] else None
                )
                res.scalar_one_or_none.return_value = latest_otp
            elif "from borrower_invitations" in stmt_str:
                latest_inv = (
                    list(db_store["invitations"].values())[-1]
                    if db_store["invitations"]
                    else None
                )
                res.scalar_one_or_none.return_value = latest_inv
            elif "from borrower_accounts" in stmt_str:
                accts = list(db_store["accounts"].values())
                res.scalar_one_or_none.return_value = accts[-1] if accts else None
            elif "from borrower_devices" in stmt_str:
                devs = list(db_store["devices"].values())
                res.scalar_one_or_none.return_value = devs[-1] if devs else None
            elif "from borrower_refresh_tokens" in stmt_str:
                matched_token = None
                for param_val in params.values():
                    if (
                        isinstance(param_val, str)
                        and param_val in db_store["refresh_tokens_by_hash"]
                    ):
                        matched_token = db_store["refresh_tokens_by_hash"][param_val]
                        break
                if matched_token is None and db_store["refresh_tokens"]:
                    matched_token = list(db_store["refresh_tokens"].values())[-1]
                res.scalar_one_or_none.return_value = matched_token
            elif "from users" in stmt_str:
                res.scalar_one_or_none.return_value = officer
            elif "from borrowers" in stmt_str:
                res.scalar_one_or_none.return_value = borrower
            else:
                res.scalar_one_or_none.return_value = None
            return res

        mock_db.execute = AsyncMock(side_effect=mock_execute)
        mock_db.commit = AsyncMock()
        mock_db.rollback = AsyncMock()
        mock_db.flush = AsyncMock()
        mock_db.refresh = AsyncMock()

        async def _mock_db_gen():
            yield mock_db

        app.dependency_overrides[get_db] = _mock_db_gen

        try:
            async with AsyncClient(
                transport=ASGITransport(app=app), base_url="http://test"
            ) as client:
                # 3. Officer creates borrower invitation code
                officer_token = create_token(officer, "access")
                inv_res = await client.post(
                    f"/api/v1/borrowers/{borrower.id}/client-invitation",
                    headers={"Authorization": f"Bearer {officer_token}"},
                    json={"expiresInHours": 72},
                )
                self.assertEqual(inv_res.status_code, 201)
                inv_data = inv_res.json()
                raw_inv_code = inv_data["invitationCode"]
                self.assertEqual(len(raw_inv_code), 6)

                # 4. Borrower requests OTP
                phone_num = "09179876543"
                otp_req_res = await client.post(
                    "/api/v1/client/auth/request-otp",
                    json={"phoneNumber": phone_num, "invitationCode": raw_inv_code},
                )
                self.assertEqual(otp_req_res.status_code, 200)

                # 5. Retrieve dev OTP
                norm_phone = "+639179876543"
                dev_otp = dev_otp_provider.last_delivered_otp.get(norm_phone)
                self.assertIsNotNone(dev_otp)

                # 6 & 7. Borrower verifies OTP and receives tokens
                verify_res = await client.post(
                    "/api/v1/client/auth/verify-otp",
                    json={
                        "phoneNumber": phone_num,
                        "otp": dev_otp,
                        "invitationCode": raw_inv_code,
                        "deviceIdentifier": "device_e2e_uuid_99",
                        "platform": "android",
                    },
                )
                self.assertEqual(verify_res.status_code, 200)
                verify_data = verify_res.json()
                access_token = verify_data["accessToken"]
                refresh_token = verify_data["refreshToken"]
                borrower_acct_id = verify_data["borrowerAccountId"]
                self.assertIsNotNone(access_token)
                self.assertIsNotNone(refresh_token)

                # 8 & 9. Borrower calls GET /api/v1/client/me
                profile_res = await client.get(
                    "/api/v1/client/me",
                    headers={"Authorization": f"Bearer {access_token}"},
                )
                self.assertEqual(profile_res.status_code, 200)
                prof_data = profile_res.json()
                self.assertEqual(prof_data["borrowerId"], borrower.id)
                self.assertEqual(prof_data["borrowerAccountId"], borrower_acct_id)
                self.assertEqual(prof_data["firstName"], "Maria")

                # 10. Borrower registers device
                dev_res = await client.post(
                    "/api/v1/client/devices",
                    headers={"Authorization": f"Bearer {access_token}"},
                    json={
                        "deviceIdentifier": "device_e2e_uuid_99",
                        "platform": "android",
                        "pushToken": "fcm_token_sample_123",
                    },
                )
                self.assertEqual(dev_res.status_code, 200)
                dev_data = dev_res.json()
                self.assertTrue(dev_data["isActive"])

                # 11 & 12. Rotate refresh token
                refresh_res = await client.post(
                    "/api/v1/client/auth/refresh",
                    json={"refreshToken": refresh_token},
                )
                self.assertEqual(refresh_res.status_code, 200)
                new_token_data = refresh_res.json()
                new_access_token = new_token_data["accessToken"]
                new_refresh_token = new_token_data["refreshToken"]
                self.assertNotEqual(refresh_token, new_refresh_token)

                # 13. Re-use of old refresh token is rejected (401)
                reuse_res = await client.post(
                    "/api/v1/client/auth/refresh",
                    json={"refreshToken": refresh_token},
                )
                self.assertEqual(reuse_res.status_code, 401)

                # 14. Borrower logs out
                logout_res = await client.post(
                    "/api/v1/client/auth/logout",
                    headers={"Authorization": f"Bearer {new_access_token}"},
                    json={"refreshToken": new_refresh_token},
                )
                self.assertEqual(logout_res.status_code, 204)

                # 16. Borrower token cannot access officer endpoints
                officer_endpoint_res = await client.get(
                    "/api/v1/loans",
                    headers={"Authorization": f"Bearer {new_access_token}"},
                )
                self.assertEqual(officer_endpoint_res.status_code, 401)

                # 17. Officer token cannot access borrower profile endpoint
                borrower_me_res = await client.get(
                    "/api/v1/client/me",
                    headers={"Authorization": f"Bearer {officer_token}"},
                )
                self.assertEqual(borrower_me_res.status_code, 401)

        finally:
            app.dependency_overrides.pop(get_db, None)


if __name__ == "__main__":
    unittest.main()
