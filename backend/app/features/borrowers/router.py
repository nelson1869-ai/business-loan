"""Authenticated borrower CRUD routes."""

from typing import Annotated

from fastapi import APIRouter, Header, HTTPException, Query, Response, status
from sqlalchemy.exc import IntegrityError

from app.core.dependencies import CurrentUser, DbSession
from app.features.borrowers.schemas import (
    BorrowerCreate,
    BorrowerResponse,
    BorrowerUpdate,
)
from app.services import borrower_service

router = APIRouter(prefix="/api/v1/borrowers", tags=["Borrowers"])


@router.get("", response_model=list[BorrowerResponse])
async def list_all_borrowers(
    db: DbSession,
    current_user: CurrentUser,
    response: Response,
    borrower_status: Annotated[str | None, Query(alias="status")] = None,
    offset: Annotated[int, Query(ge=0)] = 0,
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
) -> list[BorrowerResponse]:
    """List a filtered, paginated borrower page."""
    del current_user
    borrowers, total = await borrower_service.list_borrowers(
        db, borrower_status, offset, limit
    )
    response.headers["X-Total-Count"] = str(total)
    return [BorrowerResponse.model_validate(item) for item in borrowers]


@router.post("", response_model=BorrowerResponse, status_code=status.HTTP_201_CREATED)
async def register_borrower(
    payload: BorrowerCreate,
    db: DbSession,
    current_user: CurrentUser,
    transaction_uuid: Annotated[str | None, Header(alias="X-Transaction-UUID")] = None,
) -> BorrowerResponse:
    """Register one borrower and write a redacted audit record."""
    del transaction_uuid
    try:
        borrower = await borrower_service.create_borrower(db, payload, current_user)
        await db.commit()
    except IntegrityError as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Borrower ID or national ID already exists",
        ) from error
    await db.refresh(borrower)
    return BorrowerResponse.model_validate(borrower)


@router.get("/{borrower_id}", response_model=BorrowerResponse)
async def get_one_borrower(
    borrower_id: str,
    db: DbSession,
    current_user: CurrentUser,
) -> BorrowerResponse:
    """Return one non-deleted borrower by UUID."""
    del current_user
    borrower = await borrower_service.get_borrower(db, borrower_id)
    if borrower is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Borrower not found"
        )
    return BorrowerResponse.model_validate(borrower)


@router.put("/{borrower_id}", response_model=BorrowerResponse)
async def replace_borrower(
    borrower_id: str,
    payload: BorrowerUpdate,
    db: DbSession,
    current_user: CurrentUser,
) -> BorrowerResponse:
    """Update a borrower and write a redacted audit record."""
    borrower = await borrower_service.get_borrower(db, borrower_id)
    if borrower is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Borrower not found"
        )
    try:
        borrower = await borrower_service.update_borrower(
            db, borrower, payload, current_user
        )
        await db.commit()
    except IntegrityError as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="National ID already exists",
        ) from error
    await db.refresh(borrower)
    return BorrowerResponse.model_validate(borrower)


@router.delete("/{borrower_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove_borrower(
    borrower_id: str,
    db: DbSession,
    current_user: CurrentUser,
) -> Response:
    """Soft-delete a borrower and write a redacted audit record."""
    borrower = await borrower_service.get_borrower(db, borrower_id)
    if borrower is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Borrower not found"
        )
    try:
        await borrower_service.delete_borrower(db, borrower, current_user)
    except borrower_service.BorrowerHasOpenLoansError as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(error),
        ) from error
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
