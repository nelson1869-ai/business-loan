"""Persistent officer note model."""

from datetime import datetime
from uuid import uuid4

from sqlalchemy import DateTime, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Note(Base):
    """An authenticated officer observation linked to a borrower or loan."""

    __tablename__ = "notes"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid4())
    )
    borrower_id: Mapped[str] = mapped_column(
        ForeignKey("borrowers.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    loan_id: Mapped[str | None] = mapped_column(
        ForeignKey("loans.id", ondelete="RESTRICT"), nullable=True, index=True
    )
    author_user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    category: Mapped[str] = mapped_column(
        String(40), nullable=False, default="General"
    )
    content: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    author: Mapped["User"] = relationship()


from app.models.user import User  # noqa: E402
