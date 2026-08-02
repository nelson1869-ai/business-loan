"""Borrower persistence model."""

from datetime import date, datetime

from sqlalchemy import Date, DateTime, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship, validates

from app.core.database import Base
from app.core.phone_numbers import normalize_ph_phone_number


class Borrower(Base):
    """A borrower record stored using snake_case PostgreSQL columns."""

    __tablename__ = "borrowers"
    __table_args__ = (
        UniqueConstraint(
            "phone_normalized",
            name="uq_borrowers_phone_normalized",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)
    national_id: Mapped[str] = mapped_column(
        String(100), nullable=False, unique=True, index=True
    )
    phone: Mapped[str] = mapped_column(String(32), nullable=False)
    phone_normalized: Mapped[str] = mapped_column(
        String(13), nullable=False, index=True
    )
    date_of_birth: Mapped[date] = mapped_column(Date, nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    loans: Mapped[list["Loan"]] = relationship(back_populates="borrower")

    @validates("phone")
    def normalize_phone(self, _key: str, value: str) -> str:
        """Canonicalize ORM-created borrowers and set their unique identity."""
        normalized = normalize_ph_phone_number(value)
        self.phone_normalized = normalized
        return normalized


from app.features.loans.models import Loan  # noqa: E402
