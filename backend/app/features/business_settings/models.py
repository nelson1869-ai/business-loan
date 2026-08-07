"""Singleton business presentation configuration."""

from datetime import datetime
from decimal import Decimal

from sqlalchemy import CheckConstraint, DateTime, Numeric, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class BusinessSetting(Base):
    __tablename__ = "business_settings"
    __table_args__ = (
        CheckConstraint(
            "currency_code ~ '^[A-Z]{3}$'",
            name="ck_business_settings_currency_code",
        ),
        CheckConstraint(
            "default_monthly_estimate_rate >= 0",
            name="ck_business_settings_estimate_rate",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    business_name: Mapped[str] = mapped_column(String(160), nullable=False)
    currency_code: Mapped[str] = mapped_column(String(3), nullable=False)
    receipt_footer: Mapped[str] = mapped_column(Text, nullable=False, default="")
    timezone: Mapped[str] = mapped_column(String(64), nullable=False, default="UTC")
    default_monthly_estimate_rate: Mapped[Decimal | None] = mapped_column(
        Numeric(10, 8), nullable=True
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
