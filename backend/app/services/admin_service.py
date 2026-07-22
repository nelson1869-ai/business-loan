"""Bulk data-reset and seeding service for development tooling."""

from datetime import date, datetime, timedelta
from decimal import Decimal
from uuid import uuid4

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.borrower import Borrower
from app.models.loan import Loan
from app.models.user import User
from app.schemas.loan import LoanCreate
from app.schemas.payment import PaymentCreate
from app.services import loan_service, payment_service


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


async def seed_database(db: AsyncSession, current_user: User) -> dict:
    """Seed native database tables with Overdue, Due Today, and Paid loan records."""
    await reset_all_data(db, current_user)

    today = date.today()
    one_month_ago = today - timedelta(days=30)
    three_months_ago = today - timedelta(days=90)
    four_months_ago = today - timedelta(days=120)
    five_months_ago = today - timedelta(days=150)

    # 1. Borrowers
    john = Borrower(
        id=str(uuid4()),
        first_name="John",
        last_name="Smith",
        national_id=f"ID-{uuid4().hex[:6]}-001",
        phone="+254701234567",
        date_of_birth=date(1990, 5, 15),
        status="Active",
    )
    mary = Borrower(
        id=str(uuid4()),
        first_name="Mary",
        last_name="Johnson",
        national_id=f"ID-{uuid4().hex[:6]}-002",
        phone="+254712345678",
        date_of_birth=date(1995, 8, 22),
        status="Pending",
    )
    robert = Borrower(
        id=str(uuid4()),
        first_name="Robert",
        last_name="Williams",
        national_id=f"ID-{uuid4().hex[:6]}-003",
        phone="+254723456789",
        date_of_birth=date(1988, 11, 3),
        status="Active",
    )
    patricia = Borrower(
        id=str(uuid4()),
        first_name="Patricia",
        last_name="Brown",
        national_id=f"ID-{uuid4().hex[:6]}-004",
        phone="+254734567890",
        date_of_birth=date(1992, 4, 10),
        status="Active",
    )
    james = Borrower(
        id=str(uuid4()),
        first_name="James",
        last_name="Miller",
        national_id=f"ID-{uuid4().hex[:6]}-005",
        phone="+254745678901",
        date_of_birth=date(1985, 7, 30),
        status="Active",
    )
    db.add_all([john, mary, robert, patricia, james])
    await db.flush()

    # 2. John Smith: Active loan with installment DUE TODAY
    john_loan = await loan_service.create_loan(
        db,
        LoanCreate(
            borrower_id=john.id,
            request_id=str(uuid4()),
            original_principal=Decimal("50000.00"),
            monthly_rate=Decimal("0.10"),
            term_months=6,
            payments_per_month=1,
            start_date=one_month_ago,
            first_due_date=today,  # DUE TODAY
        ),
        current_user,
    )

    # 3. Robert Williams: OVERDUE loan
    robert_loan = await loan_service.create_loan(
        db,
        LoanCreate(
            borrower_id=robert.id,
            request_id=str(uuid4()),
            original_principal=Decimal("25000.00"),
            monthly_rate=Decimal("0.12"),
            term_months=4,
            payments_per_month=1,
            start_date=four_months_ago,
            first_due_date=three_months_ago,
        ),
        current_user,
    )
    robert_loan.status = "Overdue"
    if robert_loan.installments:
        robert_loan.installments[0].status = "Overdue"

    # 4. Patricia Brown: PAID loan
    patricia_loan = await loan_service.create_loan(
        db,
        LoanCreate(
            borrower_id=patricia.id,
            request_id=str(uuid4()),
            original_principal=Decimal("20000.00"),
            monthly_rate=Decimal("0.10"),
            term_months=3,
            payments_per_month=1,
            start_date=five_months_ago,
            first_due_date=four_months_ago,
        ),
        current_user,
    )

    # Record full early payoff on Patricia's loan
    await payment_service.record_payment(
        db,
        patricia_loan.id,
        PaymentCreate(
            request_id=str(uuid4()),
            amount=Decimal("25000.00"),
            effective_date=four_months_ago,
            note="Full early payoff",
        ),
        current_user,
    )

    await db.flush()
    return {
        "status": "ok",
        "detail": "Backend SQL seeded with Active, Overdue, Due Today, and Paid loans.",
    }

