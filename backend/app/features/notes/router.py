"""Authenticated borrower and loan note routes."""

from fastapi import APIRouter, HTTPException, Response, status

from app.core.dependencies import CurrentUser, DbSession
from app.features.notes import service as note_service
from app.features.notes.models import Note
from app.features.notes.schemas import NoteCreate, NoteResponse

router = APIRouter(prefix="/api/v1", tags=["Notes"])


def _response(note: Note, current_user: CurrentUser) -> NoteResponse:
    return NoteResponse(
        id=note.id,
        borrower_id=note.borrower_id,
        loan_id=note.loan_id,
        author_user_id=note.author_user_id,
        author_name=note.author.username,
        category=note.category,
        content=note.content,
        created_at=note.created_at,
        can_delete=note.author_user_id == current_user.id
        or current_user.role == "admin",
    )


@router.get("/borrowers/{borrower_id}/notes", response_model=list[NoteResponse])
async def borrower_notes(
    borrower_id: str, db: DbSession, current_user: CurrentUser
) -> list[NoteResponse]:
    try:
        notes = await note_service.list_notes(db, borrower_id)
    except LookupError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    return [_response(note, current_user) for note in notes]


@router.post(
    "/borrowers/{borrower_id}/notes",
    response_model=NoteResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_borrower_note(
    borrower_id: str,
    payload: NoteCreate,
    db: DbSession,
    current_user: CurrentUser,
) -> NoteResponse:
    try:
        note = await note_service.create_note(db, borrower_id, payload, current_user)
        await db.commit()
        note = (await note_service.list_notes(db, borrower_id))[0]
        return _response(note, current_user)
    except LookupError as error:
        await db.rollback()
        raise HTTPException(status_code=404, detail=str(error)) from error


@router.get(
    "/borrowers/{borrower_id}/loans/{loan_id}/notes",
    response_model=list[NoteResponse],
)
async def loan_notes(
    borrower_id: str, loan_id: str, db: DbSession, current_user: CurrentUser
) -> list[NoteResponse]:
    try:
        notes = await note_service.list_notes(db, borrower_id, loan_id)
    except LookupError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    return [_response(note, current_user) for note in notes]


@router.post(
    "/borrowers/{borrower_id}/loans/{loan_id}/notes",
    response_model=NoteResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_loan_note(
    borrower_id: str,
    loan_id: str,
    payload: NoteCreate,
    db: DbSession,
    current_user: CurrentUser,
) -> NoteResponse:
    try:
        await note_service.create_note(db, borrower_id, payload, current_user, loan_id)
        await db.commit()
        note = (await note_service.list_notes(db, borrower_id, loan_id))[0]
        return _response(note, current_user)
    except LookupError as error:
        await db.rollback()
        raise HTTPException(status_code=404, detail=str(error)) from error


@router.delete("/notes/{note_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_note(
    note_id: str, db: DbSession, current_user: CurrentUser
) -> Response:
    note = await db.get(Note, note_id)
    if note is None:
        raise HTTPException(status_code=404, detail="Note not found")
    try:
        await note_service.delete_note(db, note, current_user)
        await db.commit()
    except PermissionError as error:
        await db.rollback()
        raise HTTPException(status_code=403, detail=str(error)) from error
    return Response(status_code=status.HTTP_204_NO_CONTENT)
