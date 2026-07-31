"""Document service forwarder."""

from app.services.document_service import (
    create_document,
    delete_document,
    get_document_by_id,
    list_documents_for_borrower,
)

__all__ = [
    "create_document",
    "delete_document",
    "get_document_by_id",
    "list_documents_for_borrower",
]
