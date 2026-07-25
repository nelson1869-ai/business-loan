"""Administrator authorization and protection regression tests."""

import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock

from fastapi import HTTPException

from app.routers import business_settings, users
from app.schemas.business_setting import BusinessSettingUpdate
from app.schemas.user import UserRoleUpdate


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

    async def test_officer_cannot_update_business_settings(self) -> None:
        with self.assertRaises(HTTPException) as raised:
            await business_settings.update_business_settings(
                BusinessSettingUpdate(
                    businessName="Lending Nelson",
                    currencyCode="PHP",
                    receiptFooter="",
                ),
                SimpleNamespace(),
                SimpleNamespace(id="officer-1", role="officer"),
            )
        self.assertEqual(raised.exception.status_code, 403)


if __name__ == "__main__":
    unittest.main()
