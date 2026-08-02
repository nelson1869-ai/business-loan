"""Immutable loan write-off and recovery records."""

from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class LoanWriteOff(Base):
    __tablename__ = "loan_write_offs"
    __table_args__ = (
        UniqueConstraint("loan_id", name="uq_loan_write_off_loan_id"),
        UniqueConstraint("approval_request_id", name="uq_write_off_approval_request"),
        CheckConstraint("amount > 0", name="ck_loan_write_off_amount_positive"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    loan_id: Mapped[str] = mapped_column(
        ForeignKey("loans.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    approval_request_id: Mapped[str] = mapped_column(
        ForeignKey("approval_requests.id", ondelete="RESTRICT"), nullable=False
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    effective_date: Mapped[date] = mapped_column(Date, nullable=False)
    reason: Mapped[str] = mapped_column(Text, nullable=False)
    written_off_by_user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    loan: Mapped["Loan"] = relationship(back_populates="write_off")
    recoveries: Mapped[list["WriteOffRecovery"]] = relationship(
        back_populates="write_off", order_by="WriteOffRecovery.effective_date"
    )


class WriteOffRecovery(Base):
    __tablename__ = "write_off_recoveries"
    __table_args__ = (
        CheckConstraint("amount > 0", name="ck_write_off_recovery_amount_positive"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    request_id: Mapped[str] = mapped_column(String(36), nullable=False, unique=True)
    write_off_id: Mapped[str] = mapped_column(
        ForeignKey("loan_write_offs.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    effective_date: Mapped[date] = mapped_column(Date, nullable=False)
    note: Mapped[str | None] = mapped_column(Text)
    recorded_by_user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    write_off: Mapped[LoanWriteOff] = relationship(back_populates="recoveries")


from app.features.loans.models import Loan  # noqa: E402
