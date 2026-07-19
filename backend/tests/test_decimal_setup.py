"""Verify the standard-library test runner and exact decimal arithmetic."""

import unittest
from decimal import Decimal


class DecimalTestSetupTests(unittest.TestCase):
    """Provide a small smoke test for the loan-calculation test foundation."""

    def test_decimal_addition_is_exact(self) -> None:
        """Demonstrate why financial tests use Decimal instead of float."""
        total = Decimal("0.10") + Decimal("0.20")

        self.assertEqual(total, Decimal("0.30"))


if __name__ == "__main__":
    unittest.main()
