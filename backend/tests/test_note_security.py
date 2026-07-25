"""Officer note scope and deletion regression tests."""

import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock

from app.services import note_service


class NoteSecurityTests(unittest.IsolatedAsyncioTestCase):
    async def test_list_rejects_missing_borrower(self) -> None:
        db = SimpleNamespace(get=AsyncMock(return_value=None))
        with self.assertRaisesRegex(LookupError, "Borrower not found"):
            await note_service.list_notes(db, "missing")

    async def test_list_rejects_loan_from_another_borrower(self) -> None:
        db = SimpleNamespace(
            get=AsyncMock(
                side_effect=[
                    SimpleNamespace(id="borrower-1", status="Active"),
                    SimpleNamespace(id="loan-1", borrower_id="borrower-2"),
                ]
            )
        )
        with self.assertRaisesRegex(LookupError, "Loan not found"):
            await note_service.list_notes(db, "borrower-1", "loan-1")

    async def test_unrelated_officer_cannot_delete_note(self) -> None:
        note = SimpleNamespace(id="note-1", author_user_id="officer-a")
        db = SimpleNamespace()
        with self.assertRaises(PermissionError):
            await note_service.delete_note(
                db,
                note,
                SimpleNamespace(id="officer-b", role="officer"),
            )


if __name__ == "__main__":
    unittest.main()
