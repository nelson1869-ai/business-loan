"""Backend tests for /health, /health/live, and /health/ready endpoints."""

import unittest
from unittest.mock import AsyncMock, patch

from fastapi.responses import JSONResponse
from fastapi.routing import APIRoute

from app.main import app


class TestHealthAPI(unittest.IsolatedAsyncioTestCase):
    """Test suite for service health checking endpoints."""

    def test_health_routes_registered_in_openapi(self) -> None:
        """Verify health endpoints exist in OpenAPI schema."""
        paths = app.openapi()["paths"]
        self.assertIn("/health", paths)
        self.assertIn("/health/live", paths)
        self.assertIn("/health/ready", paths)

    async def test_liveness_endpoint_logic(self) -> None:
        """Verify liveness handler returns 200 without DB access."""
        route = next(r for r in app.routes if isinstance(r, APIRoute) and r.path == "/health/live")
        res = await route.endpoint()
        self.assertEqual(res, {"status": "ok", "service": "lending-nelson-api"})

    @patch("app.main.AsyncSessionFactory")
    async def test_readiness_endpoint_success(self, mock_session_factory) -> None:
        """Verify readiness handler returns 200 when database is reachable."""
        mock_session = AsyncMock()
        mock_session.execute = AsyncMock()
        mock_session_factory.return_value.__aenter__.return_value = mock_session

        route = next(r for r in app.routes if isinstance(r, APIRoute) and r.path == "/health/ready")
        res = await route.endpoint()
        self.assertEqual(res, {"status": "ready", "service": "lending-nelson-api", "database": "connected"})

    @patch("app.main.AsyncSessionFactory")
    async def test_readiness_endpoint_503_failure(self, mock_session_factory) -> None:
        """Verify readiness handler returns 503 when database is unreachable."""
        mock_session_factory.return_value.__aenter__.side_effect = Exception("Connection error")

        route = next(r for r in app.routes if isinstance(r, APIRoute) and r.path == "/health/ready")
        res = await route.endpoint()
        self.assertIsInstance(res, JSONResponse)
        self.assertEqual(res.status_code, 503)


if __name__ == "__main__":
    unittest.main()
