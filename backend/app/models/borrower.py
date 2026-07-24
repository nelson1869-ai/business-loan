"""Borrower persistence model."""

from datetime import date, datetime

from sqlalchemy import Date, DateTime, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Borrower(Base):
    """A borrower record stored using snake_case PostgreSQL columns."""

    __tablename__ = "borrowers"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)
    national_id: Mapped[str] = mapped_column(
        String(100), nullable=False, unique=True, index=True
    )
    phone: Mapped[str] = mapped_column(String(32), nullable=False)
    date_of_birth: Mapped[date] = mapped_column(Date, nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    loans: Mapped[list["Loan"]] = relationship(back_populates="borrower")


from app.models.loan import Loan  # noqa: E402
