"""Reusable Redis-first rate limiting with a bounded local fallback."""

from __future__ import annotations

import hashlib
import hmac

from app.core.assistant_rate_limiter import (
    AssistantRateLimiter as RateLimiter,
)
from app.core.assistant_rate_limiter import (
    FallbackAssistantRateLimiter as FallbackRateLimiter,
)
from app.core.assistant_rate_limiter import (
    InMemoryAssistantRateLimiter as InMemoryRateLimiter,
)
from app.core.assistant_rate_limiter import (
    RedisAssistantRateLimiter as RedisRateLimiter,
)
from app.core.assistant_rate_limiter import (
    build_assistant_rate_limiter as build_rate_limiter,
)

__all__ = [
    "FallbackRateLimiter",
    "InMemoryRateLimiter",
    "RateLimiter",
    "RedisRateLimiter",
    "build_rate_limiter",
    "opaque_rate_limit_key",
]


def opaque_rate_limit_key(namespace: str, *identities: str, secret: str) -> str:
    """Return a non-reversible, namespace-separated limiter key."""
    normalized = "\x1f".join(
        identity.strip().casefold() for identity in identities
    ).encode()
    digest = hmac.new(secret.encode(), normalized, hashlib.sha256).hexdigest()
    return f"{namespace}:{digest}"
