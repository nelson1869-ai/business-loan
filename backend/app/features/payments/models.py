"""Immutable payment ledger and allocation snapshot models."""

from datetime import date, datetime
from decimal import Decimal

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
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Payment(Base):
    """One immutable payment or reversal ledger entry."""

    __tablename__ = "payments"
    __table_args__ = (
        Index(
            "ix_payments_loan_effective_date",
            "loan_id",
            "effective_date",
        ),
        UniqueConstraint("request_id", name="uq_payments_request_id"),
        UniqueConstraint(
            "reversal_of_payment_id",
            name="uq_payments_reversal_of_payment_id",
        ),
        CheckConstraint("amount > 0", name="ck_payments_amount_positive"),
        CheckConstraint(
            "entry_type IN ('Payment', 'Reversal')",
            name="ck_payments_entry_type",
        ),
        CheckConstraint(
            "(entry_type = 'Payment' AND reversal_of_payment_id IS NULL) OR "
            "(entry_type = 'Reversal' AND reversal_of_payment_id IS NOT NULL)",
            name="ck_payments_reversal_link",
        ),
        CheckConstraint(
            "payment_method IN ('unspecified', 'cash', 'bank', 'mobile_money')",
            name="ck_payments_method",
        ),
        CheckConstraint(
            "payment_method <> 'cash' OR collection_session_id IS NOT NULL",
            name="ck_cash_payment_collection_session",
        ),
        CheckConstraint(
            "reconciliation_status IN ('unreconciled', 'reconciled', 'reversed')",
            name="ck_payments_reconciliation_status",
        ),
        UniqueConstraint("receipt_number", name="uq_payments_receipt_number"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    request_id: Mapped[str] = mapped_column(String(36), nullable=False)
    loan_id: Mapped[str] = mapped_column(
        ForeignKey("loans.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    installment_id: Mapped[str | None] = mapped_column(
        ForeignKey("installments.id", ondelete="RESTRICT"),
        nullable=True,
        index=True,
    )
    recorded_by_user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    reversal_of_payment_id: Mapped[str | None] = mapped_column(
        ForeignKey("payments.id", ondelete="RESTRICT"),
        nullable=True,
    )
    entry_type: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="Payment",
        index=True,
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    effective_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    payment_method: Mapped[str] = mapped_column(
        String(20), nullable=False, default="unspecified"
    )
    collection_session_id: Mapped[str | None] = mapped_column(
        ForeignKey("collection_sessions.id", ondelete="RESTRICT"), nullable=True
    )
    device_id: Mapped[str | None] = mapped_column(String(120), nullable=True)
    receipt_number: Mapped[str | None] = mapped_column(String(120), nullable=True)
    reconciliation_status: Mapped[str] = mapped_column(
        String(20), nullable=False, default="unreconciled"
    )
    approval_request_id: Mapped[str | None] = mapped_column(
        ForeignKey("approval_requests.id", ondelete="RESTRICT"), unique=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    loan: Mapped["Loan"] = relationship(back_populates="payments")
    installment: Mapped["Installment | None"] = relationship(back_populates="payments")
    recorded_by: Mapped["User"] = relationship(back_populates="payments_recorded")
    reversal_of: Mapped["Payment | None"] = relationship(
        remote_side="Payment.id",
        foreign_keys=[reversal_of_payment_id],
        back_populates="reversal",
    )
    reversal: Mapped["Payment | None"] = relationship(
        foreign_keys=[reversal_of_payment_id],
        back_populates="reversal_of",
        uselist=False,
    )
    allocation: Mapped["PaymentAllocation"] = relationship(
        back_populates="payment",
        uselist=False,
    )
    receipt: Mapped["PaymentReceipt | None"] = relationship(
        back_populates="payment",
        uselist=False,
        foreign_keys="[PaymentReceipt.payment_id]",
    )


class PaymentAllocation(Base):
    """Exact before/allocation/after snapshot for one payment ledger entry."""

    __tablename__ = "payment_allocations"
    __table_args__ = (
        UniqueConstraint("payment_id", name="uq_payment_allocations_payment_id"),
        CheckConstraint(
            "interest_before >= 0 AND principal_before >= 0 "
            "AND applied_interest >= 0 AND applied_principal >= 0 "
            "AND unapplied_credit >= 0 AND interest_after >= 0 "
            "AND principal_after >= 0",
            name="ck_payment_allocations_non_negative",
        ),
        CheckConstraint(
            "overdue_days >= 0", name="ck_payment_allocations_overdue_days"
        ),
        CheckConstraint(
            "scheduled_period_days > 0",
            name="ck_payment_allocations_period_days",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    payment_id: Mapped[str] = mapped_column(
        ForeignKey("payments.id", ondelete="RESTRICT"),
        nullable=False,
    )
    interest_before: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    principal_before: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    applied_interest: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    applied_principal: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    unapplied_credit: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    interest_after: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    principal_after: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    overdue_days: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    scheduled_period_days: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    payment: Mapped[Payment] = relationship(back_populates="allocation")


class PaymentReceipt(Base):
    """Immutable receipt snapshot created when a payment transaction commits."""

    __tablename__ = "payment_receipts"
    __table_args__ = (
        CheckConstraint(
            "receipt_status IN ('Confirmed', 'Reversed', 'PartiallyReversed', 'Voided')",
            name="ck_payment_receipts_status",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    payment_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("payments.id", ondelete="RESTRICT"),
        nullable=False,
        unique=True,
        index=True,
    )
    receipt_number: Mapped[str] = mapped_column(
        String(120), nullable=False, unique=True, index=True
    )
    receipt_status: Mapped[str] = mapped_column(
        String(30), nullable=False, server_default="Confirmed", index=True
    )
    borrower_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("borrowers.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    borrower_name: Mapped[str] = mapped_column(String(200), nullable=False)
    borrower_account_ref: Mapped[str] = mapped_column(String(100), nullable=False)
    loan_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("loans.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    loan_reference: Mapped[str] = mapped_column(String(100), nullable=False)
    payment_date: Mapped[date] = mapped_column(Date, nullable=False)
    payment_time: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    effective_date: Mapped[date] = mapped_column(Date, nullable=False)
    payment_method: Mapped[str] = mapped_column(String(50), nullable=False)
    external_reference: Mapped[str | None] = mapped_column(String(120), nullable=True)
    amount_received: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    balance_before_payment: Mapped[Decimal] = mapped_column(
        Numeric(18, 2), nullable=False
    )
    principal_applied: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    interest_applied: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    penalty_applied: Mapped[Decimal] = mapped_column(
        Numeric(18, 2), nullable=False, server_default="0.00"
    )
    fees_applied: Mapped[Decimal] = mapped_column(
        Numeric(18, 2), nullable=False, server_default="0.00"
    )
    unapplied_credit: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    remaining_principal: Mapped[Decimal] = mapped_column(
        Numeric(18, 2), nullable=False
    )
    outstanding_interest: Mapped[Decimal] = mapped_column(
        Numeric(18, 2), nullable=False, server_default="0.00"
    )
    overdue_amount: Mapped[Decimal] = mapped_column(
        Numeric(18, 2), nullable=False, server_default="0.00"
    )
    total_outstanding_amount: Mapped[Decimal] = mapped_column(
        Numeric(18, 2), nullable=False
    )
    next_payment_amount: Mapped[Decimal | None] = mapped_column(
        Numeric(18, 2), nullable=True
    )
    next_due_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    loan_status_after: Mapped[str] = mapped_column(String(30), nullable=False)
    recorded_by_user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    recorded_by_name: Mapped[str] = mapped_column(String(120), nullable=False)
    verification_token: Mapped[str] = mapped_column(
        String(120), nullable=False, unique=True, index=True
    )
    receipt_version: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default="1"
    )
    reversal_payment_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("payments.id", ondelete="SET NULL"), nullable=True
    )
    reversal_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    reversal_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    deterministic_explanation: Mapped[str] = mapped_column(Text, nullable=False)
    ai_explanation: Mapped[str | None] = mapped_column(Text, nullable=True)
    ai_explanation_model: Mapped[str | None] = mapped_column(
        String(50), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    payment: Mapped["Payment"] = relationship(back_populates="receipt", foreign_keys=[payment_id])


from app.features.loans.models import Installment, Loan  # noqa: E402
from app.features.users.models import User  # noqa: E402
