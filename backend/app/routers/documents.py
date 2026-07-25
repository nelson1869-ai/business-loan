"""Authenticated borrower and loan document routes."""

import base64
import binascii
from pathlib import Path

from fastapi import APIRouter, HTTPException, Response, status
from sqlalchemy import select

from app.dependencies import CurrentUser, DbSession
from app.models.borrower import Borrower
from app.models.document import Document
from app.models.loan import Loan
from app.schemas.document import DocumentCreate, DocumentResponse

router = APIRouter(prefix="/api/v1", tags=["Documents"])
_MAX_DOCUMENT_BYTES = 700_000
_ALLOWED_CONTENT_TYPES = {
    "application/pdf",
    "image/jpeg",
    "image/png",
    "image/webp",
}


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


async def _list(db: DbSession, borrower_id: str, loan_id: str | None) -> list[Document]:
    query = select(Document).where(Document.borrower_id == borrower_id)
    query = query.where(Document.loan_id.is_(None) if loan_id is None else Document.loan_id == loan_id)
    return list((await db.execute(query.order_by(Document.created_at.desc()))).scalars())


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
        raise HTTPException(status_code=422, detail="Invalid document content") from error
    if not content or len(content) > _MAX_DOCUMENT_BYTES:
        raise HTTPException(status_code=413, detail="Document must be no larger than 700 KB")
    document = Document(
        borrower_id=borrower_id,
        loan_id=loan_id,
        uploaded_by_user_id=user.id,
        title=payload.title.strip(),
        file_name=Path(payload.file_name).name,
        content_type=content_type,
        size_bytes=len(content),
        content=content,
    )
    db.add(document)
    await db.commit()
    await db.refresh(document)
    return document


@router.get("/borrowers/{borrower_id}/documents", response_model=list[DocumentResponse])
async def borrower_documents(
    borrower_id: str, db: DbSession, current_user: CurrentUser
) -> list[DocumentResponse]:
    await _validate_scope(db, borrower_id, None)
    return [_response(item, current_user) for item in await _list(db, borrower_id, None)]


@router.post(
    "/borrowers/{borrower_id}/documents",
    response_model=DocumentResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_borrower_document(
    borrower_id: str, payload: DocumentCreate, db: DbSession, current_user: CurrentUser
) -> DocumentResponse:
    return _response(await _create(db, current_user, borrower_id, None, payload), current_user)


@router.get(
    "/borrowers/{borrower_id}/loans/{loan_id}/documents",
    response_model=list[DocumentResponse],
)
async def loan_documents(
    borrower_id: str, loan_id: str, db: DbSession, current_user: CurrentUser
) -> list[DocumentResponse]:
    await _validate_scope(db, borrower_id, loan_id)
    return [_response(item, current_user) for item in await _list(db, borrower_id, loan_id)]


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
    if document is None:
        raise HTTPException(status_code=404, detail="Document not found")
    return Response(
        content=document.content,
        media_type=document.content_type,
        headers={"Content-Disposition": f'attachment; filename="{document.file_name}"'},
    )


@router.delete("/documents/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_document(
    document_id: str, db: DbSession, current_user: CurrentUser
) -> Response:
    document = await db.get(Document, document_id)
    if document is None:
        raise HTTPException(status_code=404, detail="Document not found")
    if document.uploaded_by_user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Document cannot be deleted")
    await db.delete(document)
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
