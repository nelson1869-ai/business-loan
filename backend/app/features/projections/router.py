"""Authenticated financial projection endpoints for Flutter."""

from datetime import date

from fastapi import APIRouter, HTTPException, Query

from app.core.dependencies import CurrentUser, DbSession
from app.features.projections.schemas import (
    DashboardProjection,
    FinancialReportProjection,
    LoanStatementProjection,
    ReceiptProjection,
)
from app.services import projection_service

router = APIRouter(prefix="/api/v1", tags=["Financial Projections"])


@router.get("/payments/{payment_id}/receipt", response_model=ReceiptProjection)
async def payment_receipt(
    payment_id: str, db: DbSession, current_user: CurrentUser
) -> ReceiptProjection:
    del current_user
    receipt = await projection_service.get_receipt(db, payment_id)
    if receipt is None:
        raise HTTPException(status_code=404, detail="Payment not found")
    return receipt


@router.get("/loans/{loan_id}/statement", response_model=LoanStatementProjection)
async def loan_statement(
    loan_id: str, db: DbSession, current_user: CurrentUser
) -> LoanStatementProjection:
    del current_user
    statement = await projection_service.get_statement(db, loan_id)
    if statement is None:
        raise HTTPException(status_code=404, detail="Loan not found")
    return statement


@router.get("/dashboard", response_model=DashboardProjection)
async def dashboard_projection(
    db: DbSession,
    current_user: CurrentUser,
    as_of: date = Query(default_factory=date.today, alias="asOf"),
) -> DashboardProjection:
    del current_user
    return await projection_service.dashboard(db, as_of)


@router.get("/reports/financial", response_model=FinancialReportProjection)
async def financial_report(
    db: DbSession,
    current_user: CurrentUser,
    date_from: date = Query(alias="dateFrom"),
    date_to: date = Query(alias="dateTo"),
) -> FinancialReportProjection:
    del current_user
    if date_to < date_from:
        raise HTTPException(status_code=422, detail="dateTo must not precede dateFrom")
    return await projection_service.financial_report(db, date_from, date_to)
