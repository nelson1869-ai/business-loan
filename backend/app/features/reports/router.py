"""Historical portfolio and collection report endpoints."""

from datetime import date

from fastapi import APIRouter, HTTPException, Query

from app.core.authorization import require_permission
from app.core.dependencies import CurrentUser, DbSession
from app.features.reports import service
from app.features.reports.schemas import (
    CollectorReconciliationReport,
    PortfolioRiskReport,
    WriteOffReport,
)

router = APIRouter(prefix="/api/v1/reports", tags=["Reports"])


@router.get("/portfolio-risk", response_model=PortfolioRiskReport)
async def portfolio_risk_report(
    db: DbSession,
    current_user: CurrentUser,
    as_of: date = Query(alias="asOf"),
):
    require_permission(current_user, "report.view")
    return await service.portfolio_risk(db, as_of)


@router.get("/collector-reconciliation", response_model=CollectorReconciliationReport)
async def collector_reconciliation_report(
    db: DbSession,
    current_user: CurrentUser,
    date_from: date = Query(alias="dateFrom"),
    date_to: date = Query(alias="dateTo"),
):
    require_permission(current_user, "report.view")
    if date_to < date_from:
        raise HTTPException(status_code=422, detail="dateTo must not precede dateFrom")
    return await service.collector_reconciliation(db, date_from, date_to)


@router.get("/write-offs", response_model=WriteOffReport)
async def write_offs_report(
    db: DbSession,
    current_user: CurrentUser,
    date_from: date = Query(alias="dateFrom"),
    date_to: date = Query(alias="dateTo"),
):
    require_permission(current_user, "report.view")
    if date_to < date_from:
        raise HTTPException(status_code=422, detail="dateTo must not precede dateFrom")
    return await service.write_off_report(db, date_from, date_to)
