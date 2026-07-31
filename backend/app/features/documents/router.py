"""Authenticated borrower and loan document routes."""

import base64
import binascii
from urllib.parse import quote
from uuid import uuid4

from fastapi import APIRouter, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.orm import load_only

from app.core.dependencies import CurrentUser, DbSession
from app.features.admin_assistant.models import AuditLog
from app.features.borrowers.models import Borrower
from app.features.documents.models import Document
from app.features.documents.schemas import DocumentCreate, DocumentResponse
from app.features.loans.models import Loan

router = APIRouter(prefix="/api/v1", tags=["Documents"])
_MAX_DOCUMENT_BYTES = 700_000
_ALLOWED_CONTENT_TYPES = {
    "application/pdf",
    "image/jpeg",
    "image/png",
    "image/webp",
}
_EXTENSION_CONTENT_TYPES = {
    "pdf": "application/pdf",
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "webp": "image/webp",
}


def _safe_file_name(value: str) -> str:
    normalized = value.replace("\\", "/").rsplit("/", maxsplit=1)[-1]
    normalized = "".join(
        character
        for character in normalized
        if character not in {'"', "\r", "\n", "\x00"}
    ).strip()
    return normalized[:255] or "document"


def _detected_content_type(content: bytes) -> str | None:
    if content.startswith(b"%PDF-"):
        return "application/pdf"
    if content.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if content.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if len(content) >= 12 and content.startswith(b"RIFF") and content[8:12] == b"WEBP":
        return "image/webp"
    return None


def _can_access(document: Document, user: CurrentUser) -> bool:
    return document.uploaded_by_user_id == user.id or user.role == "admin"


def _audit(db: DbSession, user_id: str, action: str, document_id: str) -> None:
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=user_id,
            action=action,
            entity_name="document",
            entity_id=document_id,
            new_state_json='{"redacted":true}',
        )
    )


def _response(document: Document, user: CurrentUser) -> DocumentResponse:
    return DocumentResponse(
        id=document.id,
        borrower_id=document.borrower_id,
        loan_id=document.loan_id,
        uploaded_by_user_id=document.uploaded_by_user_id,
        title=document.title,
        file_name=document.file_name,
        content_type=document.content_type,
        size_bytes=document.size_bytes,
        created_at=document.created_at,
        can_delete=document.uploaded_by_user_id == user.id or user.role == "admin",
    )


async def _validate_scope(db: DbSession, borrower_id: str, loan_id: str | None) -> None:
    if await db.get(Borrower, borrower_id) is None:
        raise HTTPException(status_code=404, detail="Borrower not found")
    if loan_id is not None:
        loan = await db.get(Loan, loan_id)
        if loan is None or loan.borrower_id != borrower_id:
            raise HTTPException(status_code=404, detail="Loan not found")


async def _list(
    db: DbSession,
    borrower_id: str,
    loan_id: str | None,
    user: CurrentUser,
) -> list[Document]:
    query = (
        select(Document)
        .options(
            load_only(
                Document.id,
                Document.borrower_id,
                Document.loan_id,
                Document.uploaded_by_user_id,
                Document.title,
                Document.file_name,
                Document.content_type,
                Document.size_bytes,
                Document.created_at,
            )
        )
        .where(Document.borrower_id == borrower_id)
    )
    query = query.where(
        Document.loan_id.is_(None) if loan_id is None else Document.loan_id == loan_id
    )
    if user.role != "admin":
        query = query.where(Document.uploaded_by_user_id == user.id)
    return list(
        (await db.execute(query.order_by(Document.created_at.desc()))).scalars()
    )


async def _create(
    db: DbSession,
    user: CurrentUser,
    borrower_id: str,
    loan_id: str | None,
    payload: DocumentCreate,
) -> Document:
    await _validate_scope(db, borrower_id, loan_id)
    content_type = payload.content_type.lower()
    if content_type not in _ALLOWED_CONTENT_TYPES:
        raise HTTPException(status_code=422, detail="Unsupported document type")
    try:
        content = base64.b64decode(payload.content_base64, validate=True)
    except (binascii.Error, ValueError) as error:
        raise HTTPException(
            status_code=422, detail="Invalid document content"
        ) from error
    if not content or len(content) > _MAX_DOCUMENT_BYTES:
        raise HTTPException(
            status_code=413, detail="Document must be no larger than 700 KB"
        )
    safe_file_name = _safe_file_name(payload.file_name)
    extension = safe_file_name.rsplit(".", maxsplit=1)[-1].lower()
    expected_type = _EXTENSION_CONTENT_TYPES.get(extension)
    detected_type = _detected_content_type(content)
    if expected_type != content_type or detected_type != content_type:
        raise HTTPException(
            status_code=422,
            detail="Document extension, content type, and file signature must match",
        )
    document = Document(
        borrower_id=borrower_id,
        loan_id=loan_id,
        uploaded_by_user_id=user.id,
        title=payload.title.strip(),
        file_name=safe_file_name,
        content_type=content_type,
        size_bytes=len(content),
        content=content,
    )
    db.add(document)
    await db.flush()
    _audit(db, user.id, "create_document", document.id)
    await db.commit()
    await db.refresh(document)
    return document


@router.get("/borrowers/{borrower_id}/documents", response_model=list[DocumentResponse])
async def borrower_documents(
    borrower_id: str, db: DbSession, current_user: CurrentUser
) -> list[DocumentResponse]:
    await _validate_scope(db, borrower_id, None)
    return [
        _response(item, current_user)
        for item in await _list(db, borrower_id, None, current_user)
    ]


@router.post(
    "/borrowers/{borrower_id}/documents",
    response_model=DocumentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_borrower_document(
    borrower_id: str, payload: DocumentCreate, db: DbSession, current_user: CurrentUser
) -> DocumentResponse:
    return _response(
        await _create(db, current_user, borrower_id, None, payload), current_user
    )


@router.get(
    "/borrowers/{borrower_id}/loans/{loan_id}/documents",
    response_model=list[DocumentResponse],
)
async def loan_documents(
    borrower_id: str, loan_id: str, db: DbSession, current_user: CurrentUser
) -> list[DocumentResponse]:
    await _validate_scope(db, borrower_id, loan_id)
    return [
        _response(item, current_user)
        for item in await _list(db, borrower_id, loan_id, current_user)
    ]


@router.post(
    "/borrowers/{borrower_id}/loans/{loan_id}/documents",
    response_model=DocumentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_loan_document(
    borrower_id: str,
    loan_id: str,
    payload: DocumentCreate,
    db: DbSession,
    current_user: CurrentUser,
) -> DocumentResponse:
    return _response(
        await _create(db, current_user, borrower_id, loan_id, payload),
        current_user,
    )


@router.get("/documents/{document_id}/content")
async def document_content(
    document_id: str, db: DbSession, current_user: CurrentUser
) -> Response:
    document = await db.get(Document, document_id)
    if document is None or not _can_access(document, current_user):
        raise HTTPException(status_code=404, detail="Document not found")
    encoded_name = quote(document.file_name, safe="")
    return Response(
        content=document.content,
        media_type=document.content_type,
        headers={
            "Content-Disposition": f"attachment; filename*=UTF-8''{encoded_name}",
            "X-Content-Type-Options": "nosniff",
        },
    )


@router.delete("/documents/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_document(
    document_id: str, db: DbSession, current_user: CurrentUser
) -> Response:
    document = await db.get(Document, document_id)
    if document is None:
        raise HTTPException(status_code=404, detail="Document not found")
    if not _can_access(document, current_user):
        raise HTTPException(status_code=404, detail="Document not found")
    _audit(db, current_user.id, "delete_document", document.id)
    await db.delete(document)
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
