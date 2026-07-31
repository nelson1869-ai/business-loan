"""Note service forwarder."""

from app.services.note_service import (
    create_note,
    list_notes_for_loan,
)

__all__ = [
    "create_note",
    "list_notes_for_loan",
]
