"""Immutable, approval-controlled loan-product policy versions."""

from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    JSON,
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


class LoanPolicyVersion(Base):
    """One version of a lending policy; active/retired versions are immutable."""

    __tablename__ = "loan_policy_versions"
    __table_args__ = (
        UniqueConstraint(
            "policy_name", "version_number", name="uq_policy_name_version"
        ),
        CheckConstraint(
            "status IN ('draft', 'active', 'retired')", name="ck_policy_status"
        ),
        CheckConstraint(
            "minimum_rate >= 0 AND maximum_rate >= minimum_rate",
            name="ck_policy_rate_range",
        ),
        CheckConstraint("currency ~ '^[A-Z]{3}$'", name="ck_policy_currency"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    policy_name: Mapped[str] = mapped_column(String(160), nullable=False, index=True)
    version_number: Mapped[int] = mapped_column(nullable=False)
    status: Mapped[str] = mapped_column(
        String(16), nullable=False, default="draft", index=True
    )
    currency: Mapped[str] = mapped_column(String(3), nullable=False)
    interest_method: Mapped[str] = mapped_column(String(64), nullable=False)
    rate_period: Mapped[str] = mapped_column(String(32), nullable=False)
    minimum_rate: Mapped[Decimal] = mapped_column(Numeric(10, 8), nullable=False)
    maximum_rate: Mapped[Decimal] = mapped_column(Numeric(10, 8), nullable=False)
    rounding_policy: Mapped[dict] = mapped_column(JSON, nullable=False)
    payment_allocation_order: Mapped[list[str]] = mapped_column(JSON, nullable=False)
    grace_period_configuration: Mapped[dict] = mapped_column(JSON, nullable=False)
    late_fee_configuration: Mapped[dict] = mapped_column(JSON, nullable=False)
    early_settlement_configuration: Mapped[dict] = mapped_column(JSON, nullable=False)
    excess_payment_treatment: Mapped[dict] = mapped_column(JSON, nullable=False)
    restructuring_policy: Mapped[dict] = mapped_column(JSON, nullable=False)
    write_off_policy: Mapped[dict] = mapped_column(JSON, nullable=False)
    contract_template_version: Mapped[str] = mapped_column(String(64), nullable=False)
    effective_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    change_reason: Mapped[str] = mapped_column(Text, nullable=False)
    created_by_user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    approved_by_user_id: Mapped[str | None] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT")
    )
    approved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    created_by = relationship("User", foreign_keys=[created_by_user_id])
    approved_by = relationship("User", foreign_keys=[approved_by_user_id])
