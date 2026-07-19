"""Authenticated loan account API routes."""

from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy.exc import IntegrityError

from app.dependencies import CurrentUser, DbSession
from app.schemas.loan import LoanCreate, LoanDetailResponse, LoanResponse, LoanStatus
from app.services import borrower_service, loan_service

router = APIRouter(prefix="/api/v1/loans", tags=["Loans"])


@router.post("", response_model=LoanDetailResponse, status_code=status.HTTP_201_CREATED)
async def create_one_loan(
    payload: LoanCreate,
    db: DbSession,
    current_user: CurrentUser,
) -> LoanDetailResponse:
    """Create an active loan and persist its complete installment schedule."""
    current_user_id = current_user.id
    if payload.request_id is not None:
        existing = await loan_service.get_loan_by_request_id(db, payload.request_id)
        if existing is not None:
            if not loan_service.loan_matches_request(existing, payload, current_user_id):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Request ID was already used for different loan terms",
                )
            return LoanDetailResponse.model_validate(existing)

    borrower = await borrower_service.get_borrower(db, payload.borrower_id)
    if borrower is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Borrower not found")
    try:
        created_loan = await loan_service.create_loan(db, payload, current_user)
        await db.commit()
    except IntegrityError as error:
        await db.rollback()
        if payload.request_id is not None:
            existing = await loan_service.get_loan_by_request_id(
                db,
                payload.request_id,
            )
            if existing is not None:
                if loan_service.loan_matches_request(existing, payload, current_user_id):
                    return LoanDetailResponse.model_validate(existing)
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Request ID was already used for different loan terms",
                ) from error
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Loan could not be created",
        ) from error
    loan = await loan_service.get_loan(db, created_loan.id)
    if loan is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Created loan could not be reloaded",
        )
    return LoanDetailResponse.model_validate(loan)


@router.get("", response_model=list[LoanResponse])
async def list_all_loans(
    db: DbSession,
    current_user: CurrentUser,
    borrower_id: Annotated[str | None, Query(alias="borrowerId")] = None,
    loan_status: Annotated[LoanStatus | None, Query(alias="status")] = None,
) -> list[LoanResponse]:
    """List loan accounts with optional borrower and status filters."""
    del current_user
    loans = await loan_service.list_loans(db, borrower_id, loan_status)
    return [LoanResponse.model_validate(loan) for loan in loans]


@router.get("/{loan_id}", response_model=LoanDetailResponse)
async def get_one_loan(
    loan_id: str,
    db: DbSession,
    current_user: CurrentUser,
) -> LoanDetailResponse:
    """Return one loan account and its ordered installment schedule."""
    del current_user
    loan = await loan_service.get_loan(db, loan_id)
    if loan is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Loan not found")
    return LoanDetailResponse.model_validate(loan)
