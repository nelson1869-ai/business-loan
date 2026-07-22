"""Bulk data-reset service for development tooling."""

from datetime import date
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.loan import Loan
from app.models.user import User


async def reset_all_data(db: AsyncSession, current_user: User) -> None:
    """Hard-delete all app data rows in FK-safe order.

    Deletion order (respects ``ondelete=RESTRICT``):
      1. payment_allocations
      2. payments
      3. installments
      4. loans
      5. audit_logs
      6. borrowers

    The ``users`` table is never touched.
    """
    tables = [
        "payment_allocations",
        "payments",
        "installments",
        "loans",
        "audit_logs",
        "borrowers",
    ]
    for table in tables:
        await db.execute(text(f"DELETE FROM {table}"))


async def update_loan_status(
    db: AsyncSession,
    loan_id: str,
    status: str,
    due_today: bool = False,
) -> None:
    """Update loan status and optionally set the first installment due date to today."""
    result = await db.execute(
        select(Loan).options(selectinload(Loan.installments)).where(Loan.id == loan_id)
    )
    loan = result.scalar_one_or_none()
    if loan:
        loan.status = status
        if due_today and loan.installments:
            loan.installments[0].due_date = date.today()
        await db.flush()

