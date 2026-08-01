"""Metadata tests for immutable payment persistence models."""

import unittest

from sqlalchemy import Numeric

from app.core.database import Base
from app.features.loans.models import Installment, Loan
from app.features.payments.models import Payment, PaymentAllocation
from app.features.users.models import User


class PaymentModelMetadataTests(unittest.TestCase):
    """Verify exact fields, relationships, and ledger safety constraints."""

    def test_payment_tables_are_registered(self) -> None:
        self.assertIn("payments", Base.metadata.tables)
        self.assertIn("payment_allocations", Base.metadata.tables)

    def test_all_money_columns_use_exact_numeric_types(self) -> None:
        payment_table = Base.metadata.tables["payments"]
        allocation_table = Base.metadata.tables["payment_allocations"]

        self._assert_money(payment_table.c.amount.type)
        for column_name in (
            "interest_before",
            "principal_before",
            "applied_interest",
            "applied_principal",
            "unapplied_credit",
            "interest_after",
            "principal_after",
        ):
            self._assert_money(allocation_table.c[column_name].type)

    def test_request_and_reversal_links_are_unique(self) -> None:
        names = {constraint.name for constraint in Payment.__table__.constraints}

        self.assertIn("uq_payments_request_id", names)
        self.assertIn("uq_payments_reversal_of_payment_id", names)
        self.assertFalse(Payment.__table__.c.request_id.nullable)

    def test_financial_foreign_keys_restrict_deletion(self) -> None:
        payment_table = Payment.__table__
        allocation_table = PaymentAllocation.__table__
        foreign_keys = [
            next(iter(payment_table.c.loan_id.foreign_keys)),
            next(iter(payment_table.c.installment_id.foreign_keys)),
            next(iter(payment_table.c.recorded_by_user_id.foreign_keys)),
            next(iter(payment_table.c.reversal_of_payment_id.foreign_keys)),
            next(iter(allocation_table.c.payment_id.foreign_keys)),
        ]

        self.assertTrue(
            all(foreign_key.ondelete == "RESTRICT" for foreign_key in foreign_keys)
        )

    def test_relationships_are_bidirectional_and_allocation_is_one_to_one(self) -> None:
        self.assertEqual(Payment.loan.property.back_populates, "payments")
        self.assertEqual(Loan.payments.property.back_populates, "loan")
        self.assertEqual(Payment.installment.property.back_populates, "payments")
        self.assertEqual(Installment.payments.property.back_populates, "installment")
        self.assertEqual(
            Payment.recorded_by.property.back_populates, "payments_recorded"
        )
        self.assertEqual(User.payments_recorded.property.back_populates, "recorded_by")
        self.assertFalse(Payment.allocation.property.uselist)
        self.assertFalse(Payment.reversal.property.uselist)

    def _assert_money(self, column_type: object) -> None:
        self.assertIsInstance(column_type, Numeric)
        assert isinstance(column_type, Numeric)
        self.assertEqual(column_type.precision, 18)
        self.assertEqual(column_type.scale, 2)


if __name__ == "__main__":
    unittest.main()
