"""Financial-integrity tests for double-entry journal validation."""

import unittest
from datetime import UTC, datetime
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

from app.features.accounting.router import _require_accounting_view, trial_balance
from app.features.accounting.service import (
    PostingLine,
    cash_deposit_lines,
    loan_disbursement_lines,
    recovery_after_write_off_lines,
    repayment_lines,
    reversing_lines,
    validate_balanced_lines,
    write_off_lines,
)


class AccountingValidationTests(unittest.TestCase):
    def test_balanced_entry_returns_exact_decimal_totals(self) -> None:
        debit, credit = validate_balanced_lines(
            (
                PostingLine("1000", debit=Decimal("125.55")),
                PostingLine("1100", credit=Decimal("100.00")),
                PostingLine("4000", credit=Decimal("25.55")),
            )
        )
        self.assertEqual(debit, Decimal("125.55"))
        self.assertEqual(credit, Decimal("125.55"))

    def test_unbalanced_entry_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "debits must equal credits"):
            validate_balanced_lines(
                (
                    PostingLine("1000", debit=Decimal("10.00")),
                    PostingLine("1100", credit=Decimal("9.99")),
                )
            )

    def test_single_line_entry_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "at least two lines"):
            validate_balanced_lines((PostingLine("1000", debit=Decimal("10.00")),))

    def test_line_cannot_have_both_or_neither_side(self) -> None:
        invalid = (
            PostingLine("1000", debit=Decimal("10.00"), credit=Decimal("10.00")),
            PostingLine("1100", credit=Decimal("10.00")),
        )
        with self.assertRaisesRegex(ValueError, "exactly one positive side"):
            validate_balanced_lines(invalid)

    def test_binary_float_amounts_are_rejected(self) -> None:
        with self.assertRaisesRegex(TypeError, "must use Decimal"):
            validate_balanced_lines(
                (
                    PostingLine("1000", debit=10.0),  # type: ignore[arg-type]
                    PostingLine("1100", credit=Decimal("10.00")),
                )
            )

    def test_payment_journal_matches_allocations_exactly(self) -> None:
        lines = repayment_lines(
            amount=Decimal("115.00"),
            principal=Decimal("90.00"),
            interest=Decimal("20.00"),
            fees=Decimal("3.00"),
            unapplied_credit=Decimal("2.00"),
        )
        self.assertEqual(validate_balanced_lines(lines), (Decimal("115.00"),) * 2)

    def test_payment_journal_rejects_allocation_mismatch(self) -> None:
        with self.assertRaisesRegex(ValueError, "components must equal"):
            repayment_lines(
                amount=Decimal("100.00"),
                principal=Decimal("99.99"),
                interest=Decimal("0.00"),
            )

    def test_reversal_restores_economic_position(self) -> None:
        original = repayment_lines(
            amount=Decimal("100.00"),
            principal=Decimal("80.00"),
            interest=Decimal("20.00"),
        )
        reversal = reversing_lines(original)
        validate_balanced_lines(reversal)
        for before, after in zip(original, reversal, strict=True):
            self.assertEqual(before.debit, after.credit)
            self.assertEqual(before.credit, after.debit)

    def test_supported_business_events_are_balanced(self) -> None:
        amount = Decimal("250.00")
        for lines in (
            loan_disbursement_lines(amount),
            cash_deposit_lines(amount),
            write_off_lines(amount),
            recovery_after_write_off_lines(amount),
        ):
            self.assertEqual(validate_balanced_lines(lines), (amount, amount))


class AccountingAuthorizationTests(unittest.TestCase):
    def test_non_admin_cannot_view_accounting(self) -> None:
        with self.assertRaises(Exception) as raised:
            _require_accounting_view(SimpleNamespace(role="officer"))
        self.assertEqual(raised.exception.status_code, 403)


class TrialBalanceTests(unittest.IsolatedAsyncioTestCase):
    async def test_trial_balance_totals_are_exact_and_balanced(self) -> None:
        db = MagicMock()
        db.execute = AsyncMock()
        result = MagicMock()
        result.all.return_value = [
            ("1000", "Cash on hand", Decimal("100.00"), Decimal("0.00")),
            ("1100", "Loans receivable", Decimal("50.00"), Decimal("20.00")),
            ("4000", "Interest income", Decimal("0.00"), Decimal("130.00")),
        ]
        db.execute.return_value = result
        cutoff = datetime(2026, 8, 2, tzinfo=UTC)

        response = await trial_balance(
            as_of=cutoff,
            db=db,
            current_user=SimpleNamespace(role="admin"),
            currency="php",
        )

        self.assertEqual(response.total_debit, Decimal("150.00"))
        self.assertEqual(response.total_credit, Decimal("150.00"))
        self.assertEqual(response.currency, "PHP")
