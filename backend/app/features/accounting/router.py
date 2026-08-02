"""Read-only accounting inspection and trial-balance endpoints."""

from datetime import datetime
from decimal import Decimal

from fastapi import APIRouter, Query
from sqlalchemy import func, select
from sqlalchemy.orm import selectinload

from app.core.authorization import require_permission
from app.core.dependencies import CurrentUser, DbSession
from app.features.accounting.models import Account, JournalEntry, JournalLine
from app.features.accounting.schemas import (
    AccountResponse,
    JournalEntryResponse,
    TrialBalanceResponse,
    TrialBalanceRow,
)

router = APIRouter(prefix="/api/v1/accounting", tags=["Accounting"])


def _require_accounting_view(user: CurrentUser) -> None:
    require_permission(user, "accounting.view")


@router.get("/accounts", response_model=list[AccountResponse])
async def list_accounts(db: DbSession, current_user: CurrentUser):
    _require_accounting_view(current_user)
    result = await db.execute(select(Account).order_by(Account.code))
    return list(result.scalars())


@router.get("/journals", response_model=list[JournalEntryResponse])
async def list_journals(
    db: DbSession,
    current_user: CurrentUser,
    offset: int = Query(default=0, ge=0),
    limit: int = Query(default=50, ge=1, le=200),
):
    _require_accounting_view(current_user)
    result = await db.execute(
        select(JournalEntry)
        .options(selectinload(JournalEntry.lines))
        .order_by(JournalEntry.posted_at.desc(), JournalEntry.id.desc())
        .offset(offset)
        .limit(limit)
    )
    return list(result.scalars())


@router.get("/trial-balance", response_model=TrialBalanceResponse)
async def trial_balance(
    as_of: datetime,
    db: DbSession,
    current_user: CurrentUser,
    currency: str = Query(default="PHP", min_length=3, max_length=3),
):
    _require_accounting_view(current_user)
    normalized_currency = currency.upper()
    result = await db.execute(
        select(
            Account.code,
            Account.name,
            func.coalesce(func.sum(JournalLine.debit), Decimal("0.00")),
            func.coalesce(func.sum(JournalLine.credit), Decimal("0.00")),
        )
        .join(JournalLine, JournalLine.account_id == Account.id)
        .join(JournalEntry, JournalEntry.id == JournalLine.journal_entry_id)
        .where(
            JournalEntry.posted_at <= as_of,
            JournalEntry.currency == normalized_currency,
        )
        .group_by(Account.code, Account.name)
        .order_by(Account.code)
    )
    rows = [
        TrialBalanceRow(
            account_code=code,
            account_name=name,
            debit=debit,
            credit=credit,
        )
        for code, name, debit, credit in result.all()
    ]
    total_debit = sum((row.debit for row in rows), Decimal("0.00"))
    total_credit = sum((row.credit for row in rows), Decimal("0.00"))
    return TrialBalanceResponse(
        as_of=as_of,
        currency=normalized_currency,
        total_debit=total_debit,
        total_credit=total_credit,
        rows=rows,
    )
