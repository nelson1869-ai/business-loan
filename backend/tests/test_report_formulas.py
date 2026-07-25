"""Focused financial projection definition tests."""

import unittest
from datetime import date, timedelta
from decimal import Decimal
from types import SimpleNamespace

from app.services.projection_service import _overdue_installment_amount


class ReportFormulaTests(unittest.TestCase):
    def test_overdue_amount_is_unpaid_due_not_full_portfolio_at_risk(self) -> None:
        as_of = date(2026, 7, 25)
        loan = SimpleNamespace(
            outstanding_principal=Decimal("900.00"),
            installments=[
                SimpleNamespace(
                    due_date=as_of - timedelta(days=1),
                    status="PartiallyPaid",
                    expected_payment=Decimal("120.00"),
                    paid_amount=Decimal("20.00"),
                ),
                SimpleNamespace(
                    due_date=as_of,
                    status="Scheduled",
                    expected_payment=Decimal("120.00"),
                    paid_amount=Decimal("0.00"),
                ),
            ],
        )

        self.assertEqual(
            _overdue_installment_amount([loan], as_of),
            Decimal("100.00"),
        )


if __name__ == "__main__":
    unittest.main()
