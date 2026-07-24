"""Authenticated loan account API routes."""

from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy.exc import IntegrityError

from app.dependencies import CurrentUser, DbSession
from app.models.loan import Loan
from app.schemas.loan import LoanCreate, LoanDetailResponse, LoanPage, LoanQuoteRequest, LoanQuoteResponse, LoanResponse, LoanStatus, LoanWorkflowAction, LoanWorkflowResponse
from app.services import borrower_service, loan_service

router = APIRouter(prefix="/api/v1/loans", tags=["Loans"])


def _net_unapplied_credit(loan: Loan) -> Decimal:
    """Sum allocation.unapplied_credit for payments minus reversals.

    Reversals carry the same [unapplied_credit] as the original payment
    but with a negative sign on the ledger, so a simple sign-based sum
    gives the net advance credit currently held for the loan.
    """
    total = Decimal("0.00")
    for payment in getattr(loan, "payments", []):
        alloc = getattr(payment, "allocation", None)
        if alloc is None:
            continue
        if payment.entry_type == "Payment":
            total += alloc.unapplied_credit
        elif payment.entry_type == "Reversal":
            total -= alloc.unapplied_credit
    # Never return a negative credit (can happen after a reversal restores state).
    return max(total, Decimal("0.00"))


def _detail(loan: Loan) -> LoanDetailResponse:
    """Build a [LoanDetailResponse] with the computed net unapplied credit."""
    response = LoanDetailResponse.model_validate(loan)
    response.unapplied_credit = _net_unapplied_credit(loan)
    return response



@router.post("/quote", response_model=LoanQuoteResponse)
async def quote_loan(
    payload: LoanQuoteRequest,
    current_user: CurrentUser,
) -> LoanQuoteResponse:
    """Return an authenticated, non-persistent loan quote."""
    del current_user
    return loan_service.build_quote(payload)


@router.post("/drafts", response_model=LoanDetailResponse, status_code=status.HTTP_201_CREATED)
async def create_draft_loan(payload: LoanCreate, db: DbSession, current_user: CurrentUser) -> LoanDetailResponse:
    """Create a draft for the explicit approval/disbursement workflow."""
    borrower = await borrower_service.get_borrower(db, payload.borrower_id)
    if borrower is None:
        raise HTTPException(status_code=404, detail="Borrower not found")
    loan = await loan_service.create_loan(db, payload, current_user, initial_status="Draft")
    await db.commit()
    reloaded = await loan_service.get_loan(db, loan.id)
    return _detail(reloaded)


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
            return _detail(existing)

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
                    return _detail(existing)
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
    return _detail(loan)


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


@router.get("/page", response_model=LoanPage)
async def page_all_loans(
    db: DbSession,
    current_user: CurrentUser,
    borrower_id: Annotated[str | None, Query(alias="borrowerId")] = None,
    loan_status: Annotated[LoanStatus | None, Query(alias="status")] = None,
    offset: Annotated[int, Query(ge=0)] = 0,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
) -> LoanPage:
    """Return a stable paginated loan envelope without changing the legacy list."""
    del current_user
    loans, total = await loan_service.page_loans(db, borrower_id, loan_status, offset, limit)
    return LoanPage(items=[LoanResponse.model_validate(item) for item in loans], total=total, offset=offset, limit=limit)


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
    return _detail(loan)


@router.post("/{loan_id}/workflow/{action}", response_model=LoanWorkflowResponse)
async def transition_one_loan(loan_id: str, action: LoanWorkflowAction, db: DbSession, current_user: CurrentUser) -> LoanWorkflowResponse:
    """Apply a validated loan lifecycle command."""
    try:
        loan, occurred_at = await loan_service.transition_loan(db, loan_id, action, current_user)
        await db.commit()
    except ValueError as error:
        await db.rollback()
        raise HTTPException(status_code=404 if "not found" in str(error).lower() else 409, detail=str(error)) from error
    return LoanWorkflowResponse(loan_id=loan.id, action=action, status=loan.status, occurred_at=occurred_at)
