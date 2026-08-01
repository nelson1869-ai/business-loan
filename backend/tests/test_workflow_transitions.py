"""Backend tests for loan workflow lifecycle transitions and state safety."""

import unittest
from datetime import UTC, datetime
from decimal import Decimal
from unittest.mock import AsyncMock, MagicMock

from app.features.loans import service as loan_service
from app.features.loans.models import Loan
from app.features.users.models import User


class TestLoanWorkflowTransitions(unittest.IsolatedAsyncioTestCase):
    """Test suite for loan workflow lifecycle actions and state constraints."""

    def setUp(self) -> None:
        self.user = User(
            id="00000000-0000-0000-0000-000000000001",
            username="officer",
            hashed_password="hashed_password_dummy",
            role="officer",
        )

    def _build_test_loan(self, status: str = "Draft") -> Loan:
        """Construct an in-memory loan for transition verification."""
        return Loan(
            id="10000000-0000-0000-0000-000000000001",
            request_id="20000000-0000-0000-0000-000000000001",
            borrower_id="30000000-0000-0000-0000-000000000001",
            created_by_user_id=self.user.id,
            original_principal=Decimal("10000.00"),
            outstanding_principal=Decimal("10000.00"),
            monthly_rate=Decimal("0.05"),
            term_months=6,
            payments_per_month=2,
            number_of_payments=12,
            regular_payment_amount=Decimal("950.00"),
            status=status,
            installments=[],
            payments=[],
        )

    async def test_approve_draft_loan(self) -> None:
        """Verify approving a draft loan sets approved_at timestamp."""
        loan = self._build_test_loan("Draft")
        db = AsyncMock()
        db.add = MagicMock()
        mock_res = MagicMock()
        mock_res.scalar_one_or_none.return_value = loan
        db.execute.return_value = mock_res

        updated_loan, timestamp = await loan_service.transition_loan(
            db, loan.id, "approve", self.user
        )

        self.assertIsNotNone(updated_loan.approved_at)
        self.assertEqual(updated_loan.approved_at, timestamp)

    async def test_disburse_approved_draft_loan(self) -> None:
        """Verify disbursing an approved draft loan sets disbursed_at timestamp."""
        loan = self._build_test_loan("Draft")
        loan.approved_at = datetime.now(UTC)
        db = AsyncMock()
        db.add = MagicMock()
        mock_res = MagicMock()
        mock_res.scalar_one_or_none.return_value = loan
        db.execute.return_value = mock_res

        updated_loan, timestamp = await loan_service.transition_loan(
            db, loan.id, "disburse", self.user
        )

        self.assertIsNotNone(updated_loan.disbursed_at)
        self.assertEqual(updated_loan.disbursed_at, timestamp)

    async def test_activate_disbursed_loan(self) -> None:
        """Verify activating a disbursed draft loan transitions status to Active."""
        loan = self._build_test_loan("Draft")
        loan.approved_at = datetime.now(UTC)
        loan.disbursed_at = datetime.now(UTC)
        db = AsyncMock()
        db.add = MagicMock()
        mock_res = MagicMock()
        mock_res.scalar_one_or_none.return_value = loan
        db.execute.return_value = mock_res

        updated_loan, _ = await loan_service.transition_loan(
            db, loan.id, "activate", self.user
        )

        self.assertEqual(updated_loan.status, "Active")
        self.assertIsNotNone(updated_loan.activated_at)

    async def test_invalid_disburse_without_approval_rejected(self) -> None:
        """Verify disbursing an unapproved draft raises ValueError."""
        loan = self._build_test_loan("Draft")
        db = AsyncMock()
        db.add = MagicMock()
        mock_res = MagicMock()
        mock_res.scalar_one_or_none.return_value = loan
        db.execute.return_value = mock_res

        with self.assertRaises(ValueError):
            await loan_service.transition_loan(db, loan.id, "disburse", self.user)

    async def test_invalid_completion_with_outstanding_balance_rejected(self) -> None:
        """Verify completing an active loan with outstanding principal raises ValueError."""
        loan = self._build_test_loan("Active")
        loan.outstanding_principal = Decimal("500.00")
        db = AsyncMock()
        db.add = MagicMock()
        mock_res = MagicMock()
        mock_res.scalar_one_or_none.return_value = loan
        db.execute.return_value = mock_res

        with self.assertRaises(ValueError):
            await loan_service.transition_loan(db, loan.id, "complete", self.user)

    async def test_cancel_draft_loan(self) -> None:
        """Verify cancelling an unpaid draft loan sets status to Cancelled."""
        loan = self._build_test_loan("Draft")
        db = AsyncMock()
        db.add = MagicMock()
        mock_res = MagicMock()
        mock_res.scalar_one_or_none.return_value = loan
        db.execute.return_value = mock_res

        updated_loan, _ = await loan_service.transition_loan(
            db, loan.id, "cancel", self.user
        )

        self.assertEqual(updated_loan.status, "Cancelled")
        self.assertIsNotNone(updated_loan.cancelled_at)


if __name__ == "__main__":
    unittest.main()
