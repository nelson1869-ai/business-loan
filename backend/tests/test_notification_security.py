"""Notification ownership regression tests."""

import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock

from fastapi import HTTPException

from app.features.notifications import router as notifications


class NotificationSecurityTests(unittest.IsolatedAsyncioTestCase):
    async def test_user_cannot_mark_another_users_notification_read(self) -> None:
        db = SimpleNamespace(
            get=AsyncMock(
                return_value=SimpleNamespace(
                    id="notification-1",
                    user_id="officer-b",
                    read_at=None,
                )
            )
        )

        with self.assertRaises(HTTPException) as raised:
            await notifications.mark_read(
                "notification-1",
                db,
                SimpleNamespace(id="officer-a", role="officer"),
            )

        self.assertEqual(raised.exception.status_code, 404)


if __name__ == "__main__":
    unittest.main()
