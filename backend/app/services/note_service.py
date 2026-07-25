"""Authenticated officer note persistence."""

from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.audit_log import AuditLog
from app.models.borrower import Borrower
from app.models.loan import Loan
from app.models.note import Note
from app.models.user import User
from app.schemas.note import NoteCreate


async def list_notes(
    db: AsyncSession, borrower_id: str, loan_id: str | None = None
) -> list[Note]:
    query = (
        select(Note)
        .options(selectinload(Note.author))
        .where(Note.borrower_id == borrower_id)
        .order_by(Note.created_at.desc())
    )
    if loan_id is None:
        query = query.where(Note.loan_id.is_(None))
    else:
        query = query.where(Note.loan_id == loan_id)
    return list((await db.execute(query)).scalars())


async def create_note(
    db: AsyncSession,
    borrower_id: str,
    payload: NoteCreate,
    user: User,
    loan_id: str | None = None,
) -> Note:
    borrower = await db.get(Borrower, borrower_id)
    if borrower is None or borrower.status == "Deleted":
        raise LookupError("Borrower not found")
    if loan_id is not None:
        loan = await db.get(Loan, loan_id)
        if loan is None or loan.borrower_id != borrower_id:
            raise LookupError("Loan not found for borrower")
    note = Note(
        borrower_id=borrower_id,
        loan_id=loan_id,
        author_user_id=user.id,
        category=payload.category.strip(),
        content=payload.content.strip(),
    )
    db.add(note)
    await db.flush()
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=user.id,
            action="create_note",
            entity_name="note",
            entity_id=note.id,
            new_state_json='{"content":"[REDACTED]"}',
        )
    )
    return note


async def delete_note(db: AsyncSession, note: Note, user: User) -> None:
    if note.author_user_id != user.id and user.role != "admin":
        raise PermissionError("Only the note author or an administrator may delete it")
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=user.id,
            action="delete_note",
            entity_name="note",
            entity_id=note.id,
            old_state_json='{"content":"[REDACTED]"}',
        )
    )
    await db.delete(note)
