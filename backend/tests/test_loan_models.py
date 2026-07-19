"""Metadata tests for loan and installment persistence models."""

import unittest

from sqlalchemy import Numeric

from app.database import Base
from app.models import Borrower, Installment, Loan, User


class LoanModelMetadataTests(unittest.TestCase):
    """Verify financial columns and relationships before migration creation."""

    def test_loan_and_installment_tables_are_registered(self) -> None:
        self.assertIn("loans", Base.metadata.tables)
        self.assertIn("installments", Base.metadata.tables)

    def test_money_and_rate_columns_use_exact_numeric_types(self) -> None:
        loan_table = Base.metadata.tables["loans"]
        installment_table = Base.metadata.tables["installments"]

        self._assert_numeric(loan_table.c.original_principal.type, 18, 2)
        self._assert_numeric(loan_table.c.outstanding_principal.type, 18, 2)
        self._assert_numeric(loan_table.c.monthly_rate.type, 10, 8)
        self._assert_numeric(installment_table.c.expected_payment.type, 18, 2)
        self._assert_numeric(installment_table.c.expected_interest.type, 18, 2)
        self._assert_numeric(installment_table.c.expected_principal.type, 18, 2)

    def test_model_relationships_are_bidirectional(self) -> None:
        self.assertEqual(Loan.borrower.property.back_populates, "loans")
        self.assertEqual(Borrower.loans.property.back_populates, "borrower")
        self.assertEqual(Loan.created_by.property.back_populates, "loans_created")
        self.assertEqual(User.loans_created.property.back_populates, "created_by")
        self.assertEqual(Loan.installments.property.back_populates, "loan")
        self.assertEqual(Installment.loan.property.back_populates, "installments")

    def test_financial_foreign_keys_restrict_destructive_deletion(self) -> None:
        loan_table = Base.metadata.tables["loans"]
        installment_table = Base.metadata.tables["installments"]

        borrower_fk = next(iter(loan_table.c.borrower_id.foreign_keys))
        creator_fk = next(iter(loan_table.c.created_by_user_id.foreign_keys))
        loan_fk = next(iter(installment_table.c.loan_id.foreign_keys))

        self.assertEqual(borrower_fk.ondelete, "RESTRICT")
        self.assertEqual(creator_fk.ondelete, "RESTRICT")
        self.assertEqual(loan_fk.ondelete, "RESTRICT")

    def test_request_id_is_required_and_unique(self) -> None:
        loan_table = Base.metadata.tables["loans"]

        self.assertFalse(loan_table.c.request_id.nullable)
        request_id_constraints = [
            constraint
            for constraint in loan_table.constraints
            if constraint.name == "uq_loans_request_id"
        ]
        self.assertEqual(len(request_id_constraints), 1)

    def _assert_numeric(self, column_type: object, precision: int, scale: int) -> None:
        self.assertIsInstance(column_type, Numeric)
        assert isinstance(column_type, Numeric)
        self.assertEqual(column_type.precision, precision)
        self.assertEqual(column_type.scale, scale)


if __name__ == "__main__":
    unittest.main()
