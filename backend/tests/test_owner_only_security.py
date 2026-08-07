from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import ASGITransport, AsyncClient

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.features.users.models import User
from app.main import app


async def mock_get_db():
    mock_session = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_session.execute.return_value = mock_result
    yield mock_session


@pytest.mark.asyncio
async def test_non_owner_roles_denied_owner_receipts() -> None:
    app.dependency_overrides[get_db] = mock_get_db
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        # 1. Admin role -> Denied (403)
        app.dependency_overrides[get_current_user] = lambda: User(
            id="admin-100", username="admin", role="admin", hashed_password="dummy"
        )
        resp_admin = await client.get(
            "/api/v1/owner/receipts/by-payment/dummy-pmt-id"
        )
        assert resp_admin.status_code == 403

        # 2. Officer role -> Denied (403)
        app.dependency_overrides[get_current_user] = lambda: User(
            id="officer-100", username="officer", role="officer", hashed_password="dummy"
        )
        resp_officer = await client.get(
            "/api/v1/owner/receipts/by-payment/dummy-pmt-id"
        )
        assert resp_officer.status_code == 403

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_owner_role_allowed_owner_receipts() -> None:
    app.dependency_overrides[get_db] = mock_get_db
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        # Owner role -> Allowed (returns 404 because payment doesn't exist, rather than 403 forbidden)
        app.dependency_overrides[get_current_user] = lambda: User(
            id="owner-100", username="owner", role="owner", hashed_password="dummy"
        )
        resp = await client.get(
            "/api/v1/owner/receipts/by-payment/dummy-pmt-id"
        )
        assert resp.status_code == 404

    app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_removed_approval_api_returns_404() -> None:
    app.dependency_overrides[get_db] = mock_get_db
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://testserver"
    ) as client:
        app.dependency_overrides[get_current_user] = lambda: User(
            id="owner-100", username="owner", role="owner", hashed_password="dummy"
        )
        resp = await client.get("/api/v1/approvals")
        assert resp.status_code == 404

    app.dependency_overrides.clear()
