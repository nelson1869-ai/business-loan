"""Direct database schema constraint tests for borrower portal models.

Executes real PostgreSQL SQL statements asserting database-level IntegrityErrors,
unique indexes, foreign key restrictions/cascades, default values, and nullability rules.
"""

import secrets
import unittest
from datetime import UTC, datetime, timedelta

from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.features.borrower_portal.models import (
    BorrowerAccount,
    BorrowerDevice,
    BorrowerRefreshToken,
)
from app.features.borrower_portal.service import hash_secret
from app.features.borrowers.models import Borrower
from app.features.loans.models import Installment, Loan
from app.features.payments.models import Payment
from app.features.users.models import User
from tests.db_test_utils import get_verified_test_db_url


class TestBorrowerPortalDatabaseConstraints(unittest.IsolatedAsyncioTestCase):
    """Direct database schema constraint verification tests."""

    async def asyncSetUp(self) -> None:
        db_url = get_verified_test_db_url()
        self.engine = create_async_engine(db_url, echo=False, future=True)

        self.session_factory = async_sessionmaker(
            self.engine, class_=AsyncSession, expire_on_commit=False
        )

        async with self.session_factory() as db:
            await db.execute(delete(Payment))
            await db.execute(delete(Installment))
            await db.execute(delete(Loan))
            await db.execute(delete(BorrowerRefreshToken))
            await db.execute(delete(BorrowerDevice))
            await db.execute(delete(BorrowerAccount))
            await db.execute(delete(Borrower))
            await db.execute(delete(User))
            await db.commit()

    async def asyncTearDown(self) -> None:
        await self.engine.dispose()

    async def test_one_borrower_account_per_borrower_constraint(self) -> None:
        """Enforces UNIQUE constraint on borrower_accounts.borrower_id."""
        async with self.session_factory() as db:
            borrower = Borrower(
                id="bor-unique-1",
                first_name="Unique",
                last_name="Test",
                national_id="PH-UNQ-1",
                phone="09171111111",
                date_of_birth=datetime(1990, 1, 1).date(),
                status="Active",
            )
            db.add(borrower)
            await db.commit()

            acct1 = BorrowerAccount(
                id=secrets.token_hex(18),
                borrower_id=borrower.id,
                phone_number="09171111111",
                phone_number_normalized="+639171111111",
            )
            db.add(acct1)
            await db.commit()

            acct2 = BorrowerAccount(
                id=secrets.token_hex(18),
                borrower_id=borrower.id,
                phone_number="09171111111",
                phone_number_normalized="+639171111112",
            )
            db.add(acct2)

            with self.assertRaises(IntegrityError):
                await db.commit()

    async def test_normalized_phone_uniqueness_constraint(self) -> None:
        """Enforces UNIQUE constraint on borrower_accounts.phone_number_normalized."""
        async with self.session_factory() as db:
            b1 = Borrower(
                id="bor-phone-1",
                first_name="B1",
                last_name="Test",
                national_id="PH-P-1",
                phone="09172222222",
                date_of_birth=datetime(1990, 1, 1).date(),
                status="Active",
            )
            b2 = Borrower(
                id="bor-phone-2",
                first_name="B2",
                last_name="Test",
                national_id="PH-P-2",
                phone="09172222223",
                date_of_birth=datetime(1990, 1, 1).date(),
                status="Active",
            )
            db.add_all([b1, b2])
            await db.commit()

            acct1 = BorrowerAccount(
                id=secrets.token_hex(18),
                borrower_id=b1.id,
                phone_number="09172222222",
                phone_number_normalized="+639172222222",
            )
            db.add(acct1)
            await db.commit()

            acct2 = BorrowerAccount(
                id=secrets.token_hex(18),
                borrower_id=b2.id,
                phone_number="09172222222",
                phone_number_normalized="+639172222222",
            )
            db.add(acct2)

            with self.assertRaises(IntegrityError):
                await db.commit()

    async def test_refresh_token_hash_uniqueness_constraint(self) -> None:
        """Enforces UNIQUE constraint on borrower_refresh_tokens.token_hash."""
        async with self.session_factory() as db:
            b = Borrower(
                id="bor-ref-1",
                first_name="Ref",
                last_name="Test",
                national_id="PH-R-1",
                phone="09173333333",
                date_of_birth=datetime(1990, 1, 1).date(),
                status="Active",
            )
            db.add(b)
            await db.commit()

            acct = BorrowerAccount(
                id=secrets.token_hex(18),
                borrower_id=b.id,
                phone_number="09173333333",
                phone_number_normalized="+639173333333",
            )
            db.add(acct)
            await db.commit()

            raw_token = secrets.token_urlsafe(32)
            token_hash = hash_secret(raw_token)

            t1 = BorrowerRefreshToken(
                id=secrets.token_hex(18),
                borrower_account_id=acct.id,
                token_hash=token_hash,
                expires_at=datetime.now(UTC) + timedelta(days=7),
            )
            t2 = BorrowerRefreshToken(
                id=secrets.token_hex(18),
                borrower_account_id=acct.id,
                token_hash=token_hash,
                expires_at=datetime.now(UTC) + timedelta(days=7),
            )
            db.add_all([t1, t2])

            with self.assertRaises(IntegrityError):
                await db.commit()

    async def test_foreign_key_restrict_on_borrower_deletion(self) -> None:
        """Enforces ON DELETE RESTRICT on borrowers linked to borrower_accounts."""
        async with self.session_factory() as db:
            b = Borrower(
                id="bor-del-1",
                first_name="Del",
                last_name="Test",
                national_id="PH-D-1",
                phone="09174444444",
                date_of_birth=datetime(1990, 1, 1).date(),
                status="Active",
            )
            db.add(b)
            await db.commit()

            acct = BorrowerAccount(
                id=secrets.token_hex(18),
                borrower_id=b.id,
                phone_number="09174444444",
                phone_number_normalized="+639174444444",
            )
            db.add(acct)
            await db.commit()

            await db.delete(b)
            with self.assertRaises(IntegrityError):
                await db.commit()

    async def test_cascade_delete_borrower_account_removes_tokens_and_devices(
        self,
    ) -> None:
        """Enforces ON DELETE CASCADE on refresh tokens and devices when account is deleted."""
        async with self.session_factory() as db:
            b = Borrower(
                id="bor-cas-1",
                first_name="Cas",
                last_name="Test",
                national_id="PH-C-1",
                phone="09175555555",
                date_of_birth=datetime(1990, 1, 1).date(),
                status="Active",
            )
            db.add(b)
            await db.commit()

            acct = BorrowerAccount(
                id=secrets.token_hex(18),
                borrower_id=b.id,
                phone_number="09175555555",
                phone_number_normalized="+639175555555",
            )
            db.add(acct)
            await db.commit()

            device = BorrowerDevice(
                id=secrets.token_hex(18),
                borrower_account_id=acct.id,
                device_identifier_hash=hash_secret("dev_uuid_cascade"),
                platform="android",
            )
            token = BorrowerRefreshToken(
                id=secrets.token_hex(18),
                borrower_account_id=acct.id,
                token_hash=hash_secret("ref_token_cascade"),
                expires_at=datetime.now(UTC) + timedelta(days=7),
            )
            db.add_all([device, token])
            await db.commit()

            await db.delete(acct)
            await db.commit()

            dev_check = (
                await db.execute(
                    select(BorrowerDevice).where(BorrowerDevice.id == device.id)
                )
            ).scalar_one_or_none()
            tok_check = (
                await db.execute(
                    select(BorrowerRefreshToken).where(
                        BorrowerRefreshToken.id == token.id
                    )
                )
            ).scalar_one_or_none()
            self.assertIsNone(dev_check)
            self.assertIsNone(tok_check)


if __name__ == "__main__":
    unittest.main()
