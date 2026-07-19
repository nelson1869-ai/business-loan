"""Focused tests for loan schedule persistence services."""

import unittest
from datetime import date
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import Mock

from app.models.audit_log import AuditLog
from app.models.loan import Loan
from app.schemas.loan import LoanCreate
from app.services.loan_service import build_due_dates, create_loan


class LoanDueDateTests(unittest.TestCase):
    """Verify monthly anchors and within-month payment spacing."""

    def test_twice_monthly_five_month_term_has_ten_dates(self) -> None:
        payload = _payload()

        due_dates = build_due_dates(payload)

        self.assertEqual(len(due_dates), 10)
        self.assertEqual(due_dates[:4], (
            date(2026, 8, 5),
            date(2026, 8, 20),
            date(2026, 9, 5),
            date(2026, 9, 20),
        ))
        self.assertEqual(due_dates[-1], date(2026, 12, 20))

    def test_month_end_anchor_clamps_shorter_months(self) -> None:
        payload = _payload(
            termMonths=2,
            paymentsPerMonth=1,
            startDate="2026-01-01",
            firstDueDate="2026-01-31",
        )

        self.assertEqual(
            build_due_dates(payload),
            (date(2026, 1, 31), date(2026, 2, 28)),
        )


class LoanCreationServiceTests(unittest.IsolatedAsyncioTestCase):
    """Verify that one transaction stages a loan, schedule, and audit event."""

    async def test_create_loan_stages_complete_schedule_and_audit(self) -> None:
        db = Mock()
        db.flush = Mock(return_value=None)

        async def flush() -> None:
            return None

        db.flush = flush
        user = SimpleNamespace(id="00000000-0000-4000-8000-000000000099")

        loan = await create_loan(db, _payload(), user)

        self.assertIsInstance(loan, Loan)
        self.assertEqual(loan.number_of_payments, 10)
        self.assertEqual(loan.request_id, _payload().request_id)
        self.assertEqual(len(loan.installments), 10)
        self.assertEqual(loan.installments[-1].expected_remaining_principal, Decimal("0.00"))
        self.assertEqual(loan.final_due_date, date(2026, 12, 20))
        added = [call.args[0] for call in db.add.call_args_list]
        self.assertIn(loan, added)
        audit = next(item for item in added if isinstance(item, AuditLog))
        self.assertEqual(audit.action, "CREATE_LOAN")
        self.assertEqual(audit.entity_id, loan.id)


def _payload(**overrides: object) -> LoanCreate:
    values: dict[str, object] = {
        "borrowerId": "00000000-0000-4000-8000-000000000001",
        "requestId": "00000000-0000-4000-8000-000000000002",
        "originalPrincipal": "1000.00",
        "monthlyRate": "0.10",
        "termMonths": 5,
        "paymentsPerMonth": 2,
        "startDate": "2026-08-01",
        "firstDueDate": "2026-08-05",
    }
    values.update(overrides)
    return LoanCreate.model_validate(values)


if __name__ == "__main__":
    unittest.main()
