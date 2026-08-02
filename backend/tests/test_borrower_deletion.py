"""Borrower deletion workflow regression tests."""

import unittest
from datetime import UTC, date, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock

from app.features.borrowers import service as borrower_service
from app.features.borrowers.models import Borrower
from app.features.borrowers.schemas import BorrowerCreate
from app.features.payments import service as payment_service


class BorrowerDeletionTests(unittest.IsolatedAsyncioTestCase):
    def _create_payload(self, **overrides: object) -> BorrowerCreate:
        values = {
            "id": "00000000-0000-4000-8000-000000000099",
            "firstName": "Restored",
            "lastName": "Borrower",
            "nationalId": "PHONE-ID-1",
            "phone": "09916084400",
            "dateOfBirth": date(2000, 1, 1),
            "status": "Active",
            "createdAt": datetime.now(UTC),
        }
        values.update(overrides)
        return BorrowerCreate(**values)

    async def test_open_loan_blocks_soft_delete(self) -> None:
        db = SimpleNamespace(scalar=AsyncMock(return_value=1))
        borrower = SimpleNamespace(id="borrower-1", status="Active")

        with self.assertRaisesRegex(
            borrower_service.BorrowerHasOpenLoansError,
            "loans remain open",
        ):
            await borrower_service.delete_borrower(
                db, borrower, SimpleNamespace(id="user-1")
            )

        self.assertEqual(borrower.status, "Active")

    async def test_deleted_borrower_rejects_payment_context(self) -> None:
        loan = SimpleNamespace(
            id="loan-1",
            borrower_id="borrower-1",
            status="Active",
            installments=[],
        )
        result = Mock()
        result.scalar_one_or_none.return_value = loan
        db = SimpleNamespace(
            execute=AsyncMock(return_value=result),
            scalar=AsyncMock(return_value="Deleted"),
        )

        with self.assertRaisesRegex(
            payment_service.LoanCalculationError,
            "borrower does not accept payments",
        ):
            await payment_service._locked_context(
                db,
                loan.id,
                SimpleNamespace(installment_id=None),
            )

    async def test_create_restores_exact_deleted_identity_with_audit(self) -> None:
        deleted = Borrower(
            id="00000000-0000-4000-8000-000000000001",
            first_name="Restored",
            last_name="Borrower",
            national_id="PHONE-ID-1",
            phone="09916084400",
            date_of_birth=date(2000, 1, 1),
            status="Deleted",
        )
        scalar_result = Mock()
        scalar_result.scalars.return_value = [deleted]
        db = SimpleNamespace(
            execute=AsyncMock(return_value=scalar_result),
            add=Mock(),
            flush=AsyncMock(),
        )

        restored = await borrower_service.create_borrower(
            db,
            self._create_payload(),
            SimpleNamespace(id="user-1"),
        )

        self.assertIs(restored, deleted)
        self.assertEqual(restored.id, "00000000-0000-4000-8000-000000000001")
        self.assertEqual(restored.status, "Active")
        self.assertEqual(restored.first_name, "Restored")
        db.flush.assert_awaited_once()
        audit = db.add.call_args.args[0]
        self.assertEqual(audit.action, "RESTORE_BORROWER")

    async def test_create_rejects_partial_deleted_identity_match(self) -> None:
        deleted = Borrower(
            id="00000000-0000-4000-8000-000000000001",
            first_name="Old",
            last_name="Name",
            national_id="DIFFERENT-ID",
            phone="09916084400",
            date_of_birth=date(1999, 1, 1),
            status="Deleted",
        )
        scalar_result = Mock()
        scalar_result.scalars.return_value = [deleted]
        db = SimpleNamespace(execute=AsyncMock(return_value=scalar_result))

        with self.assertRaisesRegex(
            borrower_service.BorrowerIdentityConflictError,
            "does not match the deleted borrower",
        ):
            await borrower_service.create_borrower(
                db,
                self._create_payload(),
                SimpleNamespace(id="user-1"),
            )

    async def test_identity_check_requires_both_identifiers_for_restore(self) -> None:
        deleted = Borrower(
            id="00000000-0000-4000-8000-000000000001",
            first_name="Old",
            last_name="Name",
            national_id="PHONE-ID-1",
            phone="09916084400",
            date_of_birth=date(1999, 1, 1),
            status="Deleted",
        )
        scalar_result = Mock()
        scalar_result.scalars.return_value = [deleted]
        db = SimpleNamespace(execute=AsyncMock(return_value=scalar_result))

        exact = await borrower_service.check_borrower_identity(
            db, "Old", "Name", "PHONE-ID-1", "09916084400", date(1999, 1, 1)
        )
        partial = await borrower_service.check_borrower_identity(
            db,
            "Old",
            "Name",
            "DIFFERENT-ID",
            "09916084400",
            date(1999, 1, 1),
        )

        self.assertEqual(exact[0], "restore")
        self.assertEqual(exact[2], deleted.id)
        self.assertEqual(partial[0], "conflict")
        self.assertIsNone(partial[2])

    async def test_identity_check_rejects_date_of_birth_mismatch(self) -> None:
        deleted = Borrower(
            id="00000000-0000-4000-8000-000000000001",
            first_name="Old",
            last_name="Name",
            national_id="PHONE-ID-1",
            phone="09916084400",
            date_of_birth=date(1999, 1, 1),
            status="Deleted",
        )
        scalar_result = Mock()
        scalar_result.scalars.return_value = [deleted]
        db = SimpleNamespace(execute=AsyncMock(return_value=scalar_result))

        result = await borrower_service.check_borrower_identity(
            db, "Old", "Name", "PHONE-ID-1", "09916084400", date(2000, 1, 1)
        )

        self.assertEqual(result[0], "conflict")
        self.assertIn("Date of birth", result[1])

    async def test_identity_check_rejects_name_mismatch(self) -> None:
        deleted = Borrower(
            id="00000000-0000-4000-8000-000000000001",
            first_name="Old",
            last_name="Name",
            national_id="PHONE-ID-1",
            phone="09916084400",
            date_of_birth=date(1999, 1, 1),
            status="Deleted",
        )
        scalar_result = Mock()
        scalar_result.scalars.return_value = [deleted]
        db = SimpleNamespace(execute=AsyncMock(return_value=scalar_result))

        result = await borrower_service.check_borrower_identity(
            db,
            "Different",
            "Person",
            "PHONE-ID-1",
            "09916084400",
            date(1999, 1, 1),
        )

        self.assertEqual(result[0], "conflict")
        self.assertIn("name", result[1])


if __name__ == "__main__":
    unittest.main()
