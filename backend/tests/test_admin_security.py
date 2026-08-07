"""Administrator authorization and protection regression tests."""

import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock

from fastapi import HTTPException

from app.features.business_settings import router as business_settings
from app.features.business_settings.schemas import BusinessSettingUpdate
from app.features.users import router as users
from app.features.users.schemas import UserRoleUpdate


class AdminSecurityTests(unittest.IsolatedAsyncioTestCase):
    async def test_officer_cannot_list_users(self) -> None:
        with self.assertRaises(HTTPException) as raised:
            await users.list_users(
                SimpleNamespace(),
                SimpleNamespace(id="officer-1", role="officer"),
            )
        self.assertEqual(raised.exception.status_code, 403)

    async def test_last_administrator_cannot_be_demoted(self) -> None:
        target = SimpleNamespace(id="admin-2", role="admin")
        db = SimpleNamespace(
            get=AsyncMock(return_value=target),
            scalar=AsyncMock(return_value=1),
        )
        with self.assertRaises(HTTPException) as raised:
            await users.update_user_role(
                target.id,
                UserRoleUpdate(role="officer"),
                db,
                SimpleNamespace(id="admin-1", role="admin"),
            )
        self.assertEqual(raised.exception.status_code, 409)

    async def test_owner_account_cannot_be_demoted_or_reassigned(self) -> None:
        target = SimpleNamespace(id="owner-1", role="owner")
        db = SimpleNamespace(get=AsyncMock(return_value=target))
        with self.assertRaises(HTTPException) as raised:
            await users.update_user_role(
                target.id,
                UserRoleUpdate(role="officer"),
                db,
                SimpleNamespace(id="admin-1", role="admin"),
            )
        self.assertEqual(raised.exception.status_code, 400)
        self.assertIn("owner account cannot be reassigned", raised.exception.detail)

    async def test_non_owner_cannot_access_business_settings(self) -> None:
        non_owner = SimpleNamespace(id="user-1", role="borrower")
        with self.assertRaises(HTTPException) as raised_get:
            await business_settings.get_business_settings(
                SimpleNamespace(), non_owner
            )
        self.assertEqual(raised_get.exception.status_code, 403)

        with self.assertRaises(HTTPException) as raised_put:
            await business_settings.update_business_settings(
                BusinessSettingUpdate(
                    businessName="Lending Nelson",
                    currencyCode="PHP",
                    receiptFooter="",
                ),
                SimpleNamespace(),
                non_owner,
            )
        self.assertEqual(raised_put.exception.status_code, 403)


if __name__ == "__main__":
    unittest.main()
