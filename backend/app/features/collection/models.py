"""Persisted operational state for installment-derived collection tasks."""

from datetime import date, datetime
from decimal import Decimal
from uuid import uuid4

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class CollectionTaskState(Base):
    __tablename__ = "collection_task_states"
    __table_args__ = (
        Index(
            "uq_collection_task_pending_installment",
            "loan_id",
            "installment_number",
            unique=True,
            postgresql_where=text(
                "status = 'Pending' AND installment_number IS NOT NULL"
            ),
        ),
        CheckConstraint(
            "status IN ('Pending', 'Completed', 'Cancelled')",
            name="ck_collection_tasks_status",
        ),
        CheckConstraint(
            "priority IN ('Low', 'Normal', 'High', 'Critical')",
            name="ck_collection_tasks_priority",
        ),
        CheckConstraint(
            "(task_type <> 'PromiseToPay') OR "
            "(promised_amount > 0 AND promise_date IS NOT NULL "
            "AND promise_status IN ('Pending', 'Kept', 'Broken', 'Cancelled'))",
            name="ck_collection_tasks_promise",
        ),
    )

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid4())
    )
    loan_id: Mapped[str] = mapped_column(
        ForeignKey("loans.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    borrower_id: Mapped[str] = mapped_column(
        ForeignKey("borrowers.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    installment_number: Mapped[int | None] = mapped_column(Integer, nullable=True)
    task_type: Mapped[str] = mapped_column(String(30), nullable=False)
    priority: Mapped[str] = mapped_column(String(20), nullable=False, default="Normal")
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="Pending")
    due_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_by_user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    assigned_to_user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    completed_by_user_id: Mapped[str | None] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=True
    )
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    completion_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    promised_amount: Mapped[Decimal | None] = mapped_column(
        Numeric(18, 2), nullable=True
    )
    promise_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    promise_status: Mapped[str | None] = mapped_column(String(20), nullable=True)
    linked_payment_id: Mapped[str | None] = mapped_column(
        ForeignKey("payments.id", ondelete="RESTRICT"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class CollectionSession(Base):
    """Controlled cash-custody window owned by one collector."""

    __tablename__ = "collection_sessions"
    __table_args__ = (
        Index(
            "uq_collection_session_collector_open",
            "collector_user_id",
            unique=True,
            postgresql_where=text(
                "status IN ('open', 'collecting', 'submitted', 'reviewed', "
                "'reconciled', 'deposited')"
            ),
        ),
        UniqueConstraint("deposit_reference", name="uq_collection_deposit_reference"),
        CheckConstraint(
            "status IN ('open', 'collecting', 'submitted', 'reviewed', "
            "'reconciled', 'deposited', 'closed')",
            name="ck_collection_session_status",
        ),
        CheckConstraint(
            "opening_cash >= 0 AND expected_cash >= 0 AND "
            "actual_cash >= 0 AND deposit_amount >= 0",
            name="ck_collection_session_amounts_nonnegative",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    collector_user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    opened_by_user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    opening_cash: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    expected_cash: Mapped[Decimal] = mapped_column(
        Numeric(18, 2), nullable=False, default=Decimal("0.00")
    )
    actual_cash: Mapped[Decimal] = mapped_column(
        Numeric(18, 2), nullable=False, default=Decimal("0.00")
    )
    cash_variance: Mapped[Decimal] = mapped_column(
        Numeric(18, 2), nullable=False, default=Decimal("0.00")
    )
    variance_reason: Mapped[str | None] = mapped_column(Text)
    deposit_amount: Mapped[Decimal] = mapped_column(
        Numeric(18, 2), nullable=False, default=Decimal("0.00")
    )
    deposit_reference: Mapped[str | None] = mapped_column(String(120))
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="open")
    reviewer_user_id: Mapped[str | None] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT")
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    reconciled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    deposited_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
