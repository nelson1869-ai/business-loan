"""Persisted operational state for installment-derived collection tasks."""

from datetime import datetime
from uuid import uuid4

from datetime import date
from decimal import Decimal

from sqlalchemy import Date, DateTime, ForeignKey, Integer, Numeric, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class CollectionTaskState(Base):
    __tablename__ = "collection_task_states"
    __table_args__ = (
        UniqueConstraint(
            "loan_id", "installment_number", name="uq_collection_task_installment"
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
    promised_amount: Mapped[Decimal | None] = mapped_column(Numeric(18, 2), nullable=True)
    promise_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    promise_status: Mapped[str | None] = mapped_column(String(20), nullable=True)
    linked_payment_id: Mapped[str | None] = mapped_column(
        ForeignKey("payments.id", ondelete="RESTRICT"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
