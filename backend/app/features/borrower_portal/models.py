"""Borrower portal database models."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class BorrowerAccount(Base):
    """Borrower account identity linked to a borrower record."""

    __tablename__ = "borrower_accounts"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    borrower_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("borrowers.id", ondelete="RESTRICT"),
        nullable=False,
        unique=True,
        index=True,
    )
    phone_number: Mapped[str] = mapped_column(String(32), nullable=False)
    phone_number_normalized: Mapped[str] = mapped_column(
        String(32), nullable=False, unique=True, index=True
    )
    phone_verified_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    account_status: Mapped[str] = mapped_column(
        String(20), nullable=False, server_default="pending", index=True
    )
    failed_login_attempts: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    locked_until: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    last_login_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    borrower: Mapped["Borrower"] = relationship()
    refresh_tokens: Mapped[list["BorrowerRefreshToken"]] = relationship(
        back_populates="borrower_account", cascade="all, delete-orphan"
    )
    devices: Mapped[list["BorrowerDevice"]] = relationship(
        back_populates="borrower_account", cascade="all, delete-orphan"
    )


class BorrowerInvitation(Base):
    """Officer-issued client invitation code for borrower account activation."""

    __tablename__ = "borrower_invitations"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    borrower_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("borrowers.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    invitation_code_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, index=True
    )
    used_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_by_user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    borrower: Mapped["Borrower"] = relationship()
    created_by_user: Mapped["User"] = relationship()


class BorrowerOTP(Base):
    """Temporary, hashed OTP records for SMS verification."""

    __tablename__ = "borrower_otps"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    phone_number_normalized: Mapped[str] = mapped_column(
        String(32), nullable=False, index=True
    )
    otp_code_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, index=True
    )
    attempts: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    resend_available_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    used_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class BorrowerRefreshToken(Base):
    """Hashed refresh tokens issued to borrower devices."""

    __tablename__ = "borrower_refresh_tokens"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    borrower_account_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("borrower_accounts.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    token_hash: Mapped[str] = mapped_column(
        String(128), nullable=False, unique=True, index=True
    )
    device_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, index=True
    )
    revoked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    borrower_account: Mapped["BorrowerAccount"] = relationship(
        back_populates="refresh_tokens"
    )


class BorrowerDevice(Base):
    """Registered devices associated with a borrower account."""

    __tablename__ = "borrower_devices"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    borrower_account_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("borrower_accounts.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    device_identifier_hash: Mapped[str] = mapped_column(
        String(128), nullable=False, index=True
    )
    platform: Mapped[str] = mapped_column(String(20), nullable=False)
    push_token: Mapped[str | None] = mapped_column(String(512), nullable=True)
    push_token_updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    last_seen_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default="true"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    borrower_account: Mapped["BorrowerAccount"] = relationship(back_populates="devices")


from app.features.borrowers.models import Borrower  # noqa: E402
from app.features.users.models import User  # noqa: E402
