"""Rate limiting backends for the administrative assistant."""

from __future__ import annotations

import logging
from collections import deque
from time import monotonic
from typing import Protocol

logger = logging.getLogger(__name__)


class AssistantRateLimiter(Protocol):
    """Minimal asynchronous rate-limiter contract."""

    async def allow(self, user_id: str, limit: int) -> bool:
        """Return whether one request is allowed."""


class RedisEvalClient(Protocol):
    """Subset of the async Redis client used by the limiter."""

    async def eval(self, script: str, numkeys: int, *values: object) -> object:
        """Evaluate one Lua script."""


class InMemoryAssistantRateLimiter:
    """Bounded single-process sliding-window fallback."""

    def __init__(self, *, window_seconds: int = 60, max_users: int = 10_000) -> None:
        self.window_seconds = window_seconds
        self.max_users = max_users
        self._requests: dict[str, deque[float]] = {}
        self._last_seen: dict[str, float] = {}

    async def allow(self, user_id: str, limit: int) -> bool:
        now = monotonic()
        self._cleanup(now)
        requests = self._requests.setdefault(user_id, deque())
        cutoff = now - self.window_seconds
        while requests and requests[0] <= cutoff:
            requests.popleft()
        self._last_seen[user_id] = now
        if len(requests) >= limit:
            self._cleanup(now)
            return False
        requests.append(now)
        self._cleanup(now)
        return True

    def _cleanup(self, now: float) -> None:
        cutoff = now - self.window_seconds
        inactive = [
            user_id
            for user_id, last_seen in self._last_seen.items()
            if last_seen <= cutoff
        ]
        for user_id in inactive:
            self._requests.pop(user_id, None)
            self._last_seen.pop(user_id, None)
        overflow = len(self._requests) - self.max_users
        if overflow > 0:
            oldest = sorted(self._last_seen, key=self._last_seen.get)[:overflow]
            for user_id in oldest:
                self._requests.pop(user_id, None)
                self._last_seen.pop(user_id, None)

    @property
    def tracked_users(self) -> int:
        """Expose bounded state size for tests and monitoring."""
        return len(self._requests)


class RedisAssistantRateLimiter:
    """Atomic Redis sliding-window limiter."""

    _SCRIPT = """
local key = KEYS[1]
local now = tonumber(ARGV[1])
local cutoff = tonumber(ARGV[2])
local limit = tonumber(ARGV[3])
local member = ARGV[4]
redis.call('ZREMRANGEBYSCORE', key, '-inf', cutoff)
local count = redis.call('ZCARD', key)
if count >= limit then
  redis.call('EXPIRE', key, 61)
  return 0
end
redis.call('ZADD', key, now, member)
redis.call('EXPIRE', key, 61)
return 1
"""

    def __init__(self, client: RedisEvalClient) -> None:
        self._client = client

    @classmethod
    def from_url(cls, url: str) -> RedisAssistantRateLimiter:
        from redis.asyncio import Redis

        return cls(Redis.from_url(url, encoding="utf-8", decode_responses=True))

    async def allow(self, user_id: str, limit: int) -> bool:
        import secrets
        import time

        now_ms = int(time.time() * 1000)
        result = await self._client.eval(
            self._SCRIPT,
            1,
            f"assistant-rate:{user_id}",
            now_ms,
            now_ms - 60_000,
            limit,
            f"{now_ms}:{secrets.token_hex(8)}",
        )
        return bool(result)


class FallbackAssistantRateLimiter:
    """Prefer Redis but fail safely to the bounded local limiter."""

    def __init__(
        self,
        primary: AssistantRateLimiter | None,
        fallback: InMemoryAssistantRateLimiter,
    ) -> None:
        self.primary = primary
        self.fallback = fallback
        self._primary_disabled_until = 0.0

    async def allow(self, user_id: str, limit: int) -> bool:
        now = monotonic()
        if self.primary is not None and now >= self._primary_disabled_until:
            try:
                return await self.primary.allow(user_id, limit)
            except Exception as error:
                self._primary_disabled_until = now + 30
                logger.warning(
                    "assistant_rate_limit_redis_fallback",
                    extra={"failure_type": type(error).__name__},
                )
        return await self.fallback.allow(user_id, limit)


def build_assistant_rate_limiter(
    redis_url: str | None,
) -> FallbackAssistantRateLimiter:
    """Build Redis-first limiting without requiring Redis for local operation."""
    primary: AssistantRateLimiter | None = None
    if redis_url and redis_url.strip():
        try:
            primary = RedisAssistantRateLimiter.from_url(redis_url)
        except Exception:
            primary = None
    return FallbackAssistantRateLimiter(
        primary=primary,
        fallback=InMemoryAssistantRateLimiter(),
    )
