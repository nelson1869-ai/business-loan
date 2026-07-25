"""Singleton business presentation configuration."""

from datetime import datetime

from sqlalchemy import DateTime, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class BusinessSetting(Base):
    __tablename__ = "business_settings"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    business_name: Mapped[str] = mapped_column(String(160), nullable=False)
    currency_code: Mapped[str] = mapped_column(String(3), nullable=False)
    receipt_footer: Mapped[str] = mapped_column(Text, nullable=False, default="")
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
