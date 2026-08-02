"""Balanced and idempotent accounting journal posting service."""

import json
from dataclasses import dataclass
from datetime import UTC, date, datetime
from decimal import ROUND_HALF_UP, Decimal
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.features.accounting.models import (
    Account,
    AccountingPeriod,
    JournalEntry,
    JournalLine,
)
from app.features.admin_assistant.models import AuditLog
from app.features.users.models import User

CENT = Decimal("0.01")


@dataclass(frozen=True, slots=True)
class PostingLine:
    account_code: str
    debit: Decimal = Decimal("0.00")
    credit: Decimal = Decimal("0.00")
    memo: str = ""


def validate_balanced_lines(lines: tuple[PostingLine, ...]) -> tuple[Decimal, Decimal]:
    if len(lines) < 2:
        raise ValueError("A journal entry requires at least two lines")
    total_debit = Decimal("0.00")
    total_credit = Decimal("0.00")
    for line in lines:
        if isinstance(line.debit, float) or isinstance(line.credit, float):
            raise TypeError("Journal amounts must use Decimal")
        debit = line.debit.quantize(CENT, rounding=ROUND_HALF_UP)
        credit = line.credit.quantize(CENT, rounding=ROUND_HALF_UP)
        if not ((debit > 0 and credit == 0) or (credit > 0 and debit == 0)):
            raise ValueError("Each journal line must contain exactly one positive side")
        total_debit += debit
        total_credit += credit
    if total_debit != total_credit:
        raise ValueError("Journal debits must equal credits")
    return total_debit, total_credit


async def post_journal(
    db: AsyncSession,
    *,
    actor: User,
    currency: str,
    posted_at: datetime,
    source_type: str,
    source_record_id: str,
    idempotency_key: str,
    description: str,
    lines: tuple[PostingLine, ...],
    request_id: str | None = None,
) -> JournalEntry:
    """Post one immutable balanced entry, returning an identical retry."""
    validate_balanced_lines(lines)
    existing = (
        await db.execute(
            select(JournalEntry)
            .options(selectinload(JournalEntry.lines))
            .where(JournalEntry.idempotency_key == idempotency_key)
        )
    ).scalar_one_or_none()
    if existing is not None:
        if (
            existing.source_type != source_type
            or existing.source_record_id != source_record_id
            or existing.currency != currency.upper()
        ):
            raise ValueError("Journal idempotency key was used for another source")
        return existing

    posting_date: date = posted_at.astimezone(UTC).date()
    period = (
        await db.execute(
            select(AccountingPeriod)
            .where(
                AccountingPeriod.start_date <= posting_date,
                AccountingPeriod.end_date >= posting_date,
                AccountingPeriod.status == "open",
            )
            .with_for_update()
        )
    ).scalar_one_or_none()
    if period is None:
        raise ValueError("No open accounting period covers the posting date")

    codes = {line.account_code for line in lines}
    account_rows = (
        await db.execute(
            select(Account).where(
                Account.code.in_(codes),
                Account.currency == currency.upper(),
                Account.is_active.is_(True),
            )
        )
    ).scalars()
    accounts = {account.code: account for account in account_rows}
    if set(accounts) != codes:
        raise ValueError(
            "Journal references a missing, inactive, or wrong-currency account"
        )

    entry = JournalEntry(
        id=str(uuid4()),
        period_id=period.id,
        currency=currency.upper(),
        posted_at=posted_at,
        actor_user_id=actor.id,
        source_type=source_type,
        source_record_id=source_record_id,
        idempotency_key=idempotency_key,
        request_id=request_id,
        description=description,
        status="posted",
        reconciliation_status="unreconciled",
    )
    entry.lines = [
        JournalLine(
            id=str(uuid4()),
            line_number=index,
            account_id=accounts[line.account_code].id,
            debit=line.debit.quantize(CENT, rounding=ROUND_HALF_UP),
            credit=line.credit.quantize(CENT, rounding=ROUND_HALF_UP),
            memo=line.memo,
        )
        for index, line in enumerate(lines, start=1)
    ]
    db.add(entry)
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=actor.id,
            action="ACCOUNTING_POST",
            entity_name="journal_entries",
            entity_id=entry.id,
            new_state_json=json.dumps(
                {
                    "sourceType": source_type,
                    "sourceRecordId": source_record_id,
                    "currency": currency.upper(),
                    "lineCount": len(lines),
                }
            ),
        )
    )
    await db.flush()
    return entry


def loan_disbursement_lines(amount: Decimal) -> tuple[PostingLine, ...]:
    """Recognize a disbursed loan as a receivable funded from cash."""
    return (
        PostingLine("1100", debit=amount, memo="Loan principal disbursed"),
        PostingLine("1000", credit=amount, memo="Cash released"),
    )


def repayment_lines(
    *,
    amount: Decimal,
    principal: Decimal,
    interest: Decimal,
    fees: Decimal = Decimal("0.00"),
    unapplied_credit: Decimal = Decimal("0.00"),
) -> tuple[PostingLine, ...]:
    """Build the exact journal corresponding to a payment allocation."""
    components = principal + interest + fees + unapplied_credit
    if components != amount:
        raise ValueError("Payment journal components must equal the payment amount")
    lines = [PostingLine("1000", debit=amount, memo="Payment received")]
    if principal:
        lines.append(PostingLine("1100", credit=principal, memo="Principal repaid"))
    if interest:
        lines.append(PostingLine("4000", credit=interest, memo="Interest received"))
    if fees:
        lines.append(PostingLine("4010", credit=fees, memo="Fees received"))
    if unapplied_credit:
        lines.append(
            PostingLine("2000", credit=unapplied_credit, memo="Unapplied credit")
        )
    return tuple(lines)


def reversing_lines(lines: tuple[PostingLine, ...]) -> tuple[PostingLine, ...]:
    """Create compensating lines; the original posted entry remains untouched."""
    return tuple(
        PostingLine(
            account_code=line.account_code,
            debit=line.credit,
            credit=line.debit,
            memo=f"Reversal: {line.memo}",
        )
        for line in lines
    )


def cash_deposit_lines(amount: Decimal) -> tuple[PostingLine, ...]:
    return (
        PostingLine("1010", debit=amount, memo="Cash deposited to bank"),
        PostingLine("1000", credit=amount, memo="Cash handed over"),
    )


def write_off_lines(amount: Decimal) -> tuple[PostingLine, ...]:
    return (
        PostingLine("5000", debit=amount, memo="Bad debt recognized"),
        PostingLine("1100", credit=amount, memo="Loan principal written off"),
    )


def recovery_after_write_off_lines(amount: Decimal) -> tuple[PostingLine, ...]:
    return (
        PostingLine("1000", debit=amount, memo="Cash recovery received"),
        PostingLine("4020", credit=amount, memo="Recovery income recognized"),
    )
