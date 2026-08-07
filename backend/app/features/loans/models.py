"""Loan account and installment persistence models."""

from datetime import date, datetime
from decimal import Decimal
from uuid import uuid4

from sqlalchemy import (
    JSON,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    SmallInteger,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Loan(Base):
    """A lender-approved loan account belonging to one borrower."""

    __tablename__ = "loans"
    __table_args__ = (
        Index("ix_loans_borrower_status", "borrower_id", "status"),
        UniqueConstraint("request_id", name="uq_loans_request_id"),
        CheckConstraint("original_principal > 0", name="ck_loans_original_principal"),
        CheckConstraint(
            "outstanding_principal >= 0",
            name="ck_loans_outstanding_principal",
        ),
        CheckConstraint("monthly_rate >= 0", name="ck_loans_monthly_rate"),
        CheckConstraint("term_months > 0", name="ck_loans_term_months"),
        CheckConstraint(
            "payments_per_month > 0",
            name="ck_loans_payments_per_month",
        ),
        CheckConstraint(
            "number_of_payments > 0",
            name="ck_loans_number_of_payments",
        ),
        CheckConstraint(
            "status IN ('Draft', 'Active', 'Paid', 'Overdue', 'Defaulted', 'Cancelled')",
            name="ck_loans_status",
        ),
        CheckConstraint(
            "calculation_method = 'fixed_periodic_reducing_balance'",
            name="ck_loans_calculation_method",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    request_id: Mapped[str] = mapped_column(
        String(36),
        nullable=False,
        default=lambda: str(uuid4()),
    )
    borrower_id: Mapped[str] = mapped_column(
        ForeignKey("borrowers.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    created_by_user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    policy_version_id: Mapped[str | None] = mapped_column(
        ForeignKey("loan_policy_versions.id", ondelete="RESTRICT"),
        nullable=True,
        index=True,
    )
    policy_snapshot: Mapped[dict] = mapped_column(JSON, nullable=False)
    original_principal: Mapped[Decimal] = mapped_column(
        Numeric(18, 2),
        nullable=False,
    )
    outstanding_principal: Mapped[Decimal] = mapped_column(
        Numeric(18, 2),
        nullable=False,
    )
    monthly_rate: Mapped[Decimal] = mapped_column(
        Numeric(10, 8),
        nullable=False,
    )
    term_months: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    payments_per_month: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    number_of_payments: Mapped[int] = mapped_column(Integer, nullable=False)
    regular_payment_amount: Mapped[Decimal] = mapped_column(
        Numeric(18, 2),
        nullable=False,
    )
    calculation_method: Mapped[str] = mapped_column(
        String(40),
        nullable=False,
        default="fixed_periodic_reducing_balance",
    )
    repayment_structure: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        server_default="principal_plus_interest",
        default="principal_plus_interest",
    )
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    first_due_date: Mapped[date] = mapped_column(Date, nullable=False)
    final_due_date: Mapped[date] = mapped_column(Date, nullable=False)
    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="Active",
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    approved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    approved_by_user_id: Mapped[str | None] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT")
    )
    disbursed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    disbursed_by_user_id: Mapped[str | None] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT")
    )
    activated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    defaulted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    borrower: Mapped["Borrower"] = relationship(back_populates="loans")
    created_by: Mapped["User"] = relationship(
        back_populates="loans_created", foreign_keys=[created_by_user_id]
    )
    approved_by: Mapped["User | None"] = relationship(
        foreign_keys=[approved_by_user_id]
    )
    disbursed_by: Mapped["User | None"] = relationship(
        foreign_keys=[disbursed_by_user_id]
    )
    policy_version: Mapped["LoanPolicyVersion | None"] = relationship()
    installments: Mapped[list["Installment"]] = relationship(
        back_populates="loan",
        order_by="Installment.installment_number",
    )
    payments: Mapped[list["Payment"]] = relationship(
        back_populates="loan",
        order_by="Payment.created_at",
    )
    write_off: Mapped["LoanWriteOff | None"] = relationship(
        back_populates="loan", uselist=False
    )


class Installment(Base):
    """One expected payment in an approved loan schedule."""

    __tablename__ = "installments"
    __table_args__ = (
        Index("ix_installments_status_due_date", "status", "due_date"),
        UniqueConstraint(
            "loan_id",
            "installment_number",
            name="uq_installments_loan_number",
        ),
        CheckConstraint(
            "installment_number > 0",
            name="ck_installments_number",
        ),
        CheckConstraint(
            "expected_payment >= 0 AND expected_interest >= 0 "
            "AND expected_principal >= 0 AND expected_remaining_principal >= 0 "
            "AND paid_amount >= 0",
            name="ck_installments_non_negative_amounts",
        ),
        CheckConstraint(
            "status IN ('Scheduled', 'PartiallyPaid', 'Paid', 'Overdue', 'Cancelled')",
            name="ck_installments_status",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    loan_id: Mapped[str] = mapped_column(
        ForeignKey("loans.id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    installment_number: Mapped[int] = mapped_column(Integer, nullable=False)
    due_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    expected_payment: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    expected_interest: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    expected_principal: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    expected_remaining_principal: Mapped[Decimal] = mapped_column(
        Numeric(18, 2),
        nullable=False,
    )
    paid_amount: Mapped[Decimal] = mapped_column(
        Numeric(18, 2),
        nullable=False,
        default=Decimal("0.00"),
    )
    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default="Scheduled",
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    loan: Mapped[Loan] = relationship(back_populates="installments")
    payments: Mapped[list["Payment"]] = relationship(back_populates="installment")


from app.features.borrowers.models import Borrower  # noqa: E402
from app.features.loan_policies.models import LoanPolicyVersion  # noqa: E402
from app.features.payments.models import Payment  # noqa: E402
from app.features.users.models import User  # noqa: E402
from app.features.write_offs.models import LoanWriteOff  # noqa: E402
