"""Test utilities and safety guards for PostgreSQL integration tests."""

import os
import unittest
from urllib.parse import urlparse


def get_verified_test_db_url() -> str:
    """Resolve and validate the test database connection URL.

    Enforces safety rules:
    1. Reads TEST_DATABASE_URL or DATABASE_URL from environment.
    2. In CI (CI="true"), raises RuntimeError if no URL is provided.
    3. Outside CI, raises SkipTest if no URL is provided.
    4. Validates connection scheme is PostgreSQL (postgresql / postgresql+asyncpg).
    5. Validates database name ends with '_test' (refuses non-test databases).

    Returns:
        Validated PostgreSQL connection URL.
    """
    raw_url = os.getenv("TEST_DATABASE_URL") or os.getenv("DATABASE_URL")

    if not raw_url or not raw_url.strip():
        if os.getenv("CI") == "true":
            raise RuntimeError(
                "TEST_DATABASE_URL or DATABASE_URL environment variable is required for PostgreSQL integration tests in CI"
            )
        raise unittest.SkipTest(
            "Set TEST_DATABASE_URL or DATABASE_URL to run real PostgreSQL integration tests"
        )

    parsed = urlparse(raw_url)

    # 1. Scheme check
    scheme = parsed.scheme.lower()
    if not (scheme.startswith("postgresql") or scheme.startswith("postgres")):
        raise RuntimeError(
            f"Integration tests require PostgreSQL engine dialect, got: {scheme}"
        )

    # 2. Database name check
    db_name = parsed.path.lstrip("/").split("?")[0]
    if not db_name.endswith("_test"):
        raise RuntimeError(
            f"Refusing to run integration tests against non-test database: {db_name!r}. "
            "Test database name must end with '_test'."
        )

    return raw_url
