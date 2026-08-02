"""Borrower phone normalization and uniqueness regression tests."""

import unittest
from datetime import UTC, date, datetime

from pydantic import ValidationError

from app.features.borrowers.models import Borrower
from app.features.borrowers.schemas import BorrowerCreate, BorrowerUpdate


class BorrowerPhoneNormalizationTests(unittest.TestCase):
    """Ensure all supported spellings produce one borrower identity."""

    def _payload(self, phone: str) -> BorrowerCreate:
        return BorrowerCreate(
            id="89053ae0-8f7c-4598-8130-65d80e07987c",
            firstName="Nelson",
            lastName="Fernandez",
            nationalId="PH-01869",
            phone=phone,
            dateOfBirth=date(2000, 8, 3),
            status="Active",
            createdAt=datetime.now(UTC),
        )

    def test_create_normalizes_equivalent_phone_formats(self) -> None:
        formats = (
            "09916084400",
            "+639916084400",
            "639916084400",
            "9916084400",
            "+63 (991) 608-4400",
        )
        self.assertEqual(
            {self._payload(phone).phone for phone in formats},
            {"+639916084400"},
        )

    def test_update_normalizes_phone(self) -> None:
        self.assertEqual(
            BorrowerUpdate(phone="0991 608 4400").phone,
            "+639916084400",
        )

    def test_invalid_phone_is_rejected(self) -> None:
        with self.assertRaises(ValidationError):
            self._payload("1234567")

    def test_orm_model_populates_normalized_unique_identity(self) -> None:
        borrower = Borrower(
            id="borrower-1",
            first_name="Nelson",
            last_name="Fernandez",
            national_id="PH-01869",
            phone="09916084400",
            date_of_birth=date(2000, 8, 3),
            status="Active",
        )
        self.assertEqual(borrower.phone, "+639916084400")
        self.assertEqual(borrower.phone_normalized, "+639916084400")


if __name__ == "__main__":
    unittest.main()
