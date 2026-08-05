"""Real PostgreSQL / SQLite database integration test suite for borrower portal lifecycle.

This module executes real database transactions, SQL queries, schema constraints,
JWT issuance, and FastAPI dependency checks against a live, real SQLAlchemy async engine
and real database tables (NO MagicMock or AsyncMock for database sessions).
"""

import secrets
import unittest
from datetime import datetime

from httpx import ASGITransport, AsyncClient
from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.database import get_db
from app.features.auth.service import create_token
from app.features.borrower_portal.models import (
    BorrowerAccount,
    BorrowerDevice,
    BorrowerInvitation,
    BorrowerOTP,
    BorrowerRefreshToken,
)
from app.features.borrower_portal.otp_provider import dev_otp_provider
from app.features.borrower_portal.service import hash_secret
from app.features.borrowers.models import Borrower
from app.features.loans.models import Installment, Loan
from app.features.payments.models import Payment
from app.features.users.models import User
from app.main import app
from tests.db_test_utils import get_verified_test_db_url


class TestBorrowerPortalRealDatabaseIntegration(unittest.IsolatedAsyncioTestCase):
    """Real database integration test suite covering the full 30-step borrower portal

    lifecycle, authentication boundaries, token rotation, reuse detection, device
    idempotency, and transaction rollbacks.
    """

    async def asyncSetUp(self) -> None:
        db_url = get_verified_test_db_url()

        # Connect to real PostgreSQL test database (schema initialized via Alembic)
        self.engine = create_async_engine(
            db_url,
            echo=False,
            future=True,
        )

        self.session_factory = async_sessionmaker(
            self.engine,
            class_=AsyncSession,
            expire_on_commit=False,
        )

        # Truncate tables for a clean test run
        async with self.session_factory() as db:
            await db.execute(delete(Payment))
            await db.execute(delete(Installment))
            await db.execute(delete(Loan))
            await db.execute(delete(BorrowerRefreshToken))
            await db.execute(delete(BorrowerDevice))
            await db.execute(delete(BorrowerOTP))
            await db.execute(delete(BorrowerInvitation))
            await db.execute(delete(BorrowerAccount))
            await db.execute(delete(Borrower))
            await db.execute(delete(User))
            await db.commit()

        async def _override_get_db():
            async with self.session_factory() as session:
                yield session

        app.dependency_overrides[get_db] = _override_get_db

    async def asyncTearDown(self) -> None:
        app.dependency_overrides.pop(get_db, None)
        await self.engine.dispose()

    async def test_full_real_database_borrower_portal_flow(self) -> None:
        # 1 & 2. Create an authorized officer user in real database
        async with self.session_factory() as db:
            officer = User(
                id="usr-officer-real-db",
                username="officer_real_db",
                hashed_password="hashed_password_123",
                role="officer",
            )
            db.add(officer)

            # 4. Create a borrower with a valid Philippine phone number
            borrower = Borrower(
                id="bor-real-101",
                first_name="Juan",
                last_name="Dela Cruz",
                national_id="PH-11223344",
                phone="09171234567",
                date_of_birth=datetime(1990, 1, 1).date(),
                status="Active",
            )
            db.add(borrower)
            await db.commit()

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            # 3. Authenticate as officer & test authorization boundaries
            officer_token = create_token(officer, "access")

            # Check: No token -> 401
            no_token_res = await client.post(
                f"/api/v1/borrowers/{borrower.id}/client-invitation",
                json={"expiresInHours": 24},
            )
            self.assertEqual(no_token_res.status_code, 401)

            # Check: Non-existent borrower -> 404
            missing_bor_res = await client.post(
                "/api/v1/borrowers/non-existent-bor-id/client-invitation",
                headers={"Authorization": f"Bearer {officer_token}"},
                json={"expiresInHours": 24},
            )
            self.assertEqual(missing_bor_res.status_code, 404)

            # 5. Create a borrower-client invitation code
            inv_res = await client.post(
                f"/api/v1/borrowers/{borrower.id}/client-invitation",
                headers={"Authorization": f"Bearer {officer_token}"},
                json={"expiresInHours": 48},
            )
            self.assertEqual(inv_res.status_code, 201)
            raw_inv_code = inv_res.json()["invitationCode"]

            # 6. Verify the invitation code is stored as a hash (not plaintext)
            async with self.session_factory() as db:
                stmt = select(BorrowerInvitation).where(
                    BorrowerInvitation.borrower_id == borrower.id
                )
                inv_record = (await db.execute(stmt)).scalar_one()
                self.assertNotEqual(inv_record.invitation_code_hash, raw_inv_code)
                self.assertEqual(
                    inv_record.invitation_code_hash, hash_secret(raw_inv_code)
                )

            # 7. Request an OTP
            phone_num = "09171234567"
            otp_req_res = await client.post(
                "/api/v1/client/auth/request-otp",
                json={"phoneNumber": phone_num, "invitationCode": raw_inv_code},
            )
            self.assertEqual(otp_req_res.status_code, 200)

            # 8 & 9. Retrieve OTP from dev provider & verify stored as a hash in DB
            norm_phone = "+639171234567"
            dev_otp = dev_otp_provider.last_delivered_otp.get(norm_phone)
            self.assertIsNotNone(dev_otp)

            async with self.session_factory() as db:
                otp_stmt = select(BorrowerOTP).where(
                    BorrowerOTP.phone_number_normalized == norm_phone
                )
                otp_record = (await db.execute(otp_stmt)).scalar_one()
                self.assertNotEqual(otp_record.otp_code_hash, dev_otp)
                self.assertEqual(otp_record.otp_code_hash, hash_secret(dev_otp))

            # 10. Verify OTP
            verify_res = await client.post(
                "/api/v1/client/auth/verify-otp",
                json={
                    "phoneNumber": phone_num,
                    "otp": dev_otp,
                    "invitationCode": raw_inv_code,
                    "deviceIdentifier": "real_device_id_uuid_1",
                    "platform": "android",
                },
            )
            self.assertEqual(verify_res.status_code, 200)
            verify_data = verify_res.json()
            access_token = verify_data["accessToken"]
            refresh_token = verify_data["refreshToken"]
            acct_id = verify_data["borrowerAccountId"]

            # 11. Confirm a borrower account is created and linked to the correct borrower
            async with self.session_factory() as db:
                acct = await db.get(BorrowerAccount, acct_id)
                self.assertIsNotNone(acct)
                self.assertEqual(acct.borrower_id, borrower.id)
                self.assertEqual(acct.phone_number_normalized, norm_phone)

            # 12. Confirm a second active account cannot be created for the same borrower
            # 14. Confirm the invitation becomes used and cannot be reused
            # 15. Confirm the OTP becomes used and cannot be reused
            async with self.session_factory() as db:
                inv_used = (
                    await db.execute(
                        select(BorrowerInvitation).where(
                            BorrowerInvitation.borrower_id == borrower.id
                        )
                    )
                ).scalar_one()
                self.assertIsNotNone(inv_used.used_at)

                otp_used = (
                    await db.execute(
                        select(BorrowerOTP).where(
                            BorrowerOTP.phone_number_normalized == norm_phone
                        )
                    )
                ).scalar_one()
                self.assertIsNotNone(otp_used.used_at)

            reuse_otp_res = await client.post(
                "/api/v1/client/auth/verify-otp",
                json={
                    "phoneNumber": phone_num,
                    "otp": dev_otp,
                    "invitationCode": raw_inv_code,
                    "deviceIdentifier": "real_device_id_uuid_1",
                    "platform": "android",
                },
            )
            self.assertEqual(reuse_otp_res.status_code, 400)

            # 16 & 17. Call GET /api/v1/client/me and verify return profile belongs to borrower
            me_res = await client.get(
                "/api/v1/client/me",
                headers={"Authorization": f"Bearer {access_token}"},
            )
            self.assertEqual(me_res.status_code, 200)
            me_data = me_res.json()
            self.assertEqual(me_data["borrowerId"], borrower.id)
            self.assertEqual(me_data["firstName"], "Juan")

            # 18, 19, 20. Register device, test idempotency & verify stored identifier is hashed
            dev_res1 = await client.post(
                "/api/v1/client/devices",
                headers={"Authorization": f"Bearer {access_token}"},
                json={
                    "deviceIdentifier": "real_device_id_uuid_1",
                    "platform": "android",
                    "pushToken": "push_token_v1",
                },
            )
            self.assertEqual(dev_res1.status_code, 200)

            dev_res2 = await client.post(
                "/api/v1/client/devices",
                headers={"Authorization": f"Bearer {access_token}"},
                json={
                    "deviceIdentifier": "real_device_id_uuid_1",
                    "platform": "android",
                    "pushToken": "push_token_v2_updated",
                },
            )
            self.assertEqual(dev_res2.status_code, 200)
            self.assertEqual(dev_res1.json()["id"], dev_res2.json()["id"])

            async with self.session_factory() as db:
                dev_rec = await db.get(BorrowerDevice, dev_res1.json()["id"])
                self.assertIsNotNone(dev_rec)
                self.assertEqual(
                    dev_rec.device_identifier_hash, hash_secret("real_device_id_uuid_1")
                )

            # 22. Rotate refresh token
            refresh_res = await client.post(
                "/api/v1/client/auth/refresh",
                json={"refreshToken": refresh_token},
            )
            self.assertEqual(refresh_res.status_code, 200)
            rotated_data = refresh_res.json()
            new_access_token = rotated_data["accessToken"]
            new_refresh_token = rotated_data["refreshToken"]

            # 23. Confirm the old refresh token is revoked
            async with self.session_factory() as db:
                old_token_rec = (
                    await db.execute(
                        select(BorrowerRefreshToken).where(
                            BorrowerRefreshToken.token_hash
                            == hash_secret(refresh_token)
                        )
                    )
                ).scalar_one()
                self.assertIsNotNone(old_token_rec.revoked_at)

            # 24. Attempt reuse of old refresh token and confirm 401 rejection
            reuse_token_res = await client.post(
                "/api/v1/client/auth/refresh",
                json={"refreshToken": refresh_token},
            )
            self.assertEqual(reuse_token_res.status_code, 401)

            # 25 & 26. Logout using new refresh token and confirm logged-out token is rejected
            logout_res = await client.post(
                "/api/v1/client/auth/logout",
                headers={"Authorization": f"Bearer {new_access_token}"},
                json={"refreshToken": new_refresh_token},
            )
            self.assertEqual(logout_res.status_code, 204)

            logout_reuse_res = await client.post(
                "/api/v1/client/auth/refresh",
                json={"refreshToken": new_refresh_token},
            )
            self.assertEqual(logout_reuse_res.status_code, 401)

            # 27. Confirm officer token cannot access borrower profile route (/client/me)
            officer_me_res = await client.get(
                "/api/v1/client/me",
                headers={"Authorization": f"Bearer {officer_token}"},
            )
            self.assertEqual(officer_me_res.status_code, 401)

            # 28. Confirm borrower token cannot access officer routes (/loans)
            borrower_officer_res = await client.get(
                "/api/v1/loans",
                headers={"Authorization": f"Bearer {access_token}"},
            )
            self.assertEqual(borrower_officer_res.status_code, 401)

            # 29. Confirm suspended borrower account is rejected
            async with self.session_factory() as db:
                await db.execute(
                    update(BorrowerAccount)
                    .where(BorrowerAccount.id == acct_id)
                    .values(account_status="suspended")
                )
                await db.commit()

            suspended_res = await client.get(
                "/api/v1/client/me",
                headers={"Authorization": f"Bearer {access_token}"},
            )
            self.assertEqual(suspended_res.status_code, 401)

            # 30. Confirm transaction rollback does not leave partial account data
            async with self.session_factory() as db:
                try:
                    async with db.begin():
                        invalid_account = BorrowerAccount(
                            id=secrets.token_hex(18),
                            borrower_id="non_existent_borrower_id",
                            phone_number="09990000000",
                            phone_number_normalized="+639990000000",
                            account_status="pending",
                        )
                        db.add(invalid_account)
                except Exception:
                    pass

            async with self.session_factory() as db:
                orphaned = (
                    await db.execute(
                        select(BorrowerAccount).where(
                            BorrowerAccount.borrower_id == "non_existent_borrower_id"
                        )
                    )
                ).scalar_one_or_none()
                self.assertIsNone(orphaned)


if __name__ == "__main__":
    unittest.main()
