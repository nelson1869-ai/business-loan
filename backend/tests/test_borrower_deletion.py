"""Borrower deletion workflow regression tests."""

import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock

from app.features.borrowers import service as borrower_service
from app.features.payments import service as payment_service


class BorrowerDeletionTests(unittest.IsolatedAsyncioTestCase):
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


if __name__ == "__main__":
    unittest.main()
