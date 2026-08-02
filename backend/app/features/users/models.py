"""Officer and administrator persistence model."""

from datetime import datetime

from sqlalchemy import DateTime, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class User(Base):
    """An authenticated lending officer or administrator."""

    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    username: Mapped[str] = mapped_column(
        String(100), nullable=False, unique=True, index=True
    )
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(20), nullable=False, default="officer")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    loans_created: Mapped[list["Loan"]] = relationship(
        back_populates="created_by", foreign_keys="Loan.created_by_user_id"
    )
    payments_recorded: Mapped[list["Payment"]] = relationship(
        back_populates="recorded_by"
    )


from app.features.loans.models import Loan  # noqa: E402
from app.features.payments.models import Payment  # noqa: E402
