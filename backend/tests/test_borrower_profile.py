"""Integration and security test suite for Borrower Portal Profile & Devices API."""

import secrets
import unittest
from datetime import date

from httpx import ASGITransport, AsyncClient
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.database import get_db
from app.features.borrower_portal.models import (
    BorrowerAccount,
    BorrowerDevice,
    BorrowerRefreshToken,
)
from app.features.borrower_portal.service import create_borrower_access_token
from app.features.borrowers.models import Borrower
from app.features.users.models import User
from app.main import app
from tests.db_test_utils import get_verified_test_db_url


class TestBorrowerProfileApi(unittest.IsolatedAsyncioTestCase):
    """Integration and security tests for Borrower Portal Profile & Devices API."""

    async def asyncSetUp(self) -> None:
        db_url = get_verified_test_db_url()
        self.engine = create_async_engine(db_url, echo=False, future=True)
        self.session_factory = async_sessionmaker(
            self.engine, class_=AsyncSession, expire_on_commit=False
        )

        async with self.session_factory() as db:
            await db.execute(delete(BorrowerRefreshToken))
            await db.execute(delete(BorrowerDevice))
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
        async with self.session_factory() as db:
            await db.execute(delete(BorrowerRefreshToken))
            await db.execute(delete(BorrowerDevice))
            await db.execute(delete(BorrowerAccount))
            await db.execute(delete(Borrower))
            await db.execute(delete(User))
            await db.commit()
        await self.engine.dispose()

    async def test_borrower_get_profile_success(self) -> None:
        suffix = secrets.token_hex(4)
        bor_id = f"bor-prof-{suffix}"
        acct_id = f"acct-prof-{suffix}"

        async with self.session_factory() as db:
            borrower = Borrower(
                id=bor_id,
                first_name="Maria",
                last_name="Santos",
                national_id=f"PH-PRF-{suffix}",
                phone=f"0950{suffix[:7]}",
                date_of_birth=date(1995, 5, 5),
                status="Active",
            )
            db.add(borrower)

            account = BorrowerAccount(
                id=acct_id,
                borrower_id=bor_id,
                phone_number=f"0950{suffix[:7]}",
                phone_number_normalized=f"+63950{suffix[:7]}",
                account_status="activated",
            )
            db.add(account)
            await db.commit()

        token = create_borrower_access_token(account)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            res = await client.get(
                "/api/v1/client/me",
                headers={"Authorization": f"Bearer {token}"},
            )

        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data["borrowerAccountId"], acct_id)
        self.assertEqual(data["borrowerId"], bor_id)
        self.assertEqual(data["firstName"], "Maria")
        self.assertEqual(data["lastName"], "Santos")
        self.assertEqual(data["accountStatus"], "active")

    async def test_borrower_register_device_success(self) -> None:
        suffix = secrets.token_hex(4)
        bor_id = f"bor-dev-{suffix}"
        acct_id = f"acct-dev-{suffix}"

        async with self.session_factory() as db:
            borrower = Borrower(
                id=bor_id,
                first_name="Device",
                last_name="Owner",
                national_id=f"PH-DEV-{suffix}",
                phone=f"0951{suffix[:7]}",
                date_of_birth=date(1993, 3, 3),
                status="Active",
            )
            db.add(borrower)

            account = BorrowerAccount(
                id=acct_id,
                borrower_id=bor_id,
                phone_number=f"0951{suffix[:7]}",
                phone_number_normalized=f"+63951{suffix[:7]}",
                account_status="activated",
            )
            db.add(account)
            await db.commit()

        token = create_borrower_access_token(account)

        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            res = await client.post(
                "/api/v1/client/devices",
                headers={"Authorization": f"Bearer {token}"},
                json={
                    "deviceIdentifier": f"test-device-{suffix}",
                    "platform": "android",
                    "pushToken": "sample-fcm-push-token",
                },
            )

        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data["platform"], "android")
        self.assertTrue(data["isActive"])

    async def test_borrower_get_profile_unauthorized(self) -> None:
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            res = await client.get("/api/v1/client/me")

        self.assertEqual(res.status_code, 401)
