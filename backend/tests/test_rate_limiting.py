"""Reusable rate-limit and privacy-boundary tests."""

from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException

from app.routers.auth import login
from app.schemas.auth import LoginRequest
from app.services.rate_limiter import InMemoryRateLimiter, opaque_rate_limit_key


def test_opaque_key_does_not_contain_account_or_client_identity():
    key = opaque_rate_limit_key(
        "login",
        "192.0.2.10",
        "synthetic-account",
        secret="test-only-secret-value",
    )

    assert "192.0.2.10" not in key
    assert "synthetic-account" not in key
    assert key.startswith("login:")


@pytest.mark.asyncio
async def test_login_rate_limit_returns_retry_after(monkeypatch):
    limiter = AsyncMock()
    limiter.allow.return_value = False
    request = MagicMock()
    request.client.host = "192.0.2.10"
    request.app.state = SimpleNamespace(rate_limiter=limiter)
    monkeypatch.setattr(
        "app.routers.auth.get_settings",
        lambda: SimpleNamespace(
            jwt_secret_key="test-only-secret-value",
            login_rate_limit_per_minute=5,
        ),
    )

    with pytest.raises(HTTPException) as raised:
        await login(
            LoginRequest(
                username="synthetic-account",
                password="test-only-password",
            ),
            AsyncMock(),
            request,
        )

    assert raised.value.status_code == 429
    assert raised.value.headers == {"Retry-After": "60"}
    limiter_key = limiter.allow.await_args.args[0]
    assert "synthetic-account" not in limiter_key
    assert "192.0.2.10" not in limiter_key


@pytest.mark.asyncio
async def test_local_limiter_remains_bounded():
    limiter = InMemoryRateLimiter(max_users=3)
    for index in range(20):
        assert await limiter.allow(f"opaque-{index}", 5)

    assert limiter.tracked_users <= 3
