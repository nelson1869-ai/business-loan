"""Borrower service forwarder."""

from app.services.borrower_service import (
    create_borrower,
    delete_borrower,
    get_borrower_by_id,
    get_borrower_detail,
    list_borrowers,
    update_borrower,
)

__all__ = [
    "create_borrower",
    "delete_borrower",
    "get_borrower_by_id",
    "get_borrower_detail",
    "list_borrowers",
    "update_borrower",
]
