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


async def clean_db_tables(db) -> None:
    """Safely truncate test database tables in strict foreign key order."""
    from sqlalchemy import delete
    from app.features.accounting.models import JournalEntry, JournalLine
    from app.features.admin_assistant.models import AuditLog
    from app.features.borrower_portal.models import (
        BorrowerAccount,
        BorrowerActivationCode,
        BorrowerDevice,
        BorrowerNotification,
        BorrowerPinReset,
        BorrowerRefreshToken,
        BorrowerRegistrationAudit,
        BorrowerRegistrationRequest,
    )
    from app.features.borrowers.models import Borrower
    from app.features.loans.models import Installment, Loan
    from app.features.payments.models import Payment, PaymentAllocation, PaymentReceipt
    from app.features.users.models import User

    await db.execute(delete(JournalLine))
    await db.execute(delete(JournalEntry))
    await db.execute(delete(AuditLog))
    await db.execute(delete(BorrowerNotification))
    await db.execute(delete(PaymentReceipt))
    await db.execute(delete(PaymentAllocation))
    await db.execute(delete(Payment))
    await db.execute(delete(Installment))
    await db.execute(delete(Loan))
    await db.execute(delete(BorrowerRegistrationAudit))
    await db.execute(delete(BorrowerPinReset))
    await db.execute(delete(BorrowerActivationCode))
    await db.execute(delete(BorrowerRegistrationRequest))
    await db.execute(delete(BorrowerRefreshToken))
    await db.execute(delete(BorrowerDevice))
    await db.execute(delete(BorrowerAccount))
    await db.execute(delete(Borrower))
    await db.execute(delete(User))
    await db.commit()

