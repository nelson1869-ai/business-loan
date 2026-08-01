"""Integration unit tests for operational automation outbox API endpoints."""

import unittest
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

from httpx import ASGITransport, AsyncClient

from app.core.config import get_settings
from app.core.database import get_db
from app.features.automation.models import AutomationEventOutbox
from app.main import app


class TestAutomationRouter(unittest.IsolatedAsyncioTestCase):
    async def test_automation_health_endpoint_requires_auth(self):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get("/api/v1/automation/health")
            assert response.status_code == 401

    @patch("app.core.database.get_db")
    async def test_automation_health_endpoint_with_api_key(self, mock_get_db):
        settings = get_settings()
        settings.n8n_service_api_key = "test-n8n-service-api-key-12345"

        mock_session = AsyncMock()
        mock_res = MagicMock()
        mock_res.scalar_one.return_value = 0
        mock_session.execute.return_value = mock_res

        async def _mock_db_gen():
            yield mock_session

        app.dependency_overrides[get_db] = _mock_db_gen
        try:
            async with AsyncClient(
                transport=ASGITransport(app=app), base_url="http://test"
            ) as client:
                response = await client.get(
                    "/api/v1/automation/health",
                    headers={"X-Service-API-Key": "test-n8n-service-api-key-12345"},
                )
                assert response.status_code == 200
                data = response.json()
                assert "pending_count" in data
                assert "total_count" in data
                assert "n8n_enabled" in data
        finally:
            app.dependency_overrides.pop(get_db, None)

    @patch("app.core.database.get_db")
    async def test_list_events_endpoint_with_api_key(self, mock_get_db):
        settings = get_settings()
        settings.n8n_service_api_key = "test-key-abc"

        mock_session = AsyncMock()
        event_id = str(uuid.uuid4())
        rec = AutomationEventOutbox(
            id=str(uuid.uuid4()),
            event_id=event_id,
            event_type="sync.item_failed",
            event_version=1,
            payload={"transaction_uuid": "tx-1"},
            status="pending",
            attempt_count=0,
            correlation_id=str(uuid.uuid4()),
            idempotency_key=f"sync.item_failed:{event_id}",
        )

        mock_count_res = MagicMock()
        mock_count_res.scalar_one.return_value = 1

        mock_items_res = MagicMock()
        mock_items_res.scalars().all.return_value = [rec]

        mock_session.execute.side_effect = [mock_count_res, mock_items_res]

        async def _mock_db_gen():
            yield mock_session

        app.dependency_overrides[get_db] = _mock_db_gen
        try:
            async with AsyncClient(
                transport=ASGITransport(app=app), base_url="http://test"
            ) as client:
                response = await client.get(
                    "/api/v1/automation/events?status=pending",
                    headers={"X-Service-API-Key": "test-key-abc"},
                )
                assert response.status_code == 200
                data = response.json()
                assert data["total"] == 1
                assert data["items"][0]["event_id"] == event_id
        finally:
            app.dependency_overrides.pop(get_db, None)


if __name__ == "__main__":
    unittest.main()
