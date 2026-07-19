"""Immutable payment ledger and allocation snapshot models."""

from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Payment(Base):
    """One immutable payment or reversal ledger entry."""

    __tablename__ = "payments"
    __table_args__ = (
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
        CheckConstraint("overdue_days >= 0", name="ck_payment_allocations_overdue_days"),
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


from app.models.loan import Installment, Loan  # noqa: E402
from app.models.user import User  # noqa: E402
