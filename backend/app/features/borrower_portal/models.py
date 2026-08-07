"""Borrower portal database models."""

from datetime import date, datetime
from decimal import Decimal
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from app.features.borrowers.models import Borrower
    from app.features.loans.models import Loan
    from app.features.users.models import User

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    func,
)
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
    password_hash: Mapped[str | None] = mapped_column(String(128), nullable=True)
    address: Mapped[str | None] = mapped_column(Text, nullable=True)
    id_photo_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    selfie_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    failed_login_attempts: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    locked_until: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    last_failed_login: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    last_successful_login: Mapped[datetime | None] = mapped_column(
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


class BorrowerRegistrationRequest(Base):
    """Untrusted public application awaiting an explicit staff link decision."""

    __tablename__ = "borrower_registration_requests"
    __table_args__ = (
        Index("ix_registration_pending_phone", "phone_number_normalized", "status"),
        CheckConstraint(
            "status IN ('pending','approved','rejected','cancelled','expired')",
            name="ck_registration_status",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    middle_name: Mapped[str | None] = mapped_column(String(100))
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)
    suffix: Mapped[str | None] = mapped_column(String(30))
    national_id: Mapped[str | None] = mapped_column(String(100))
    phone_number: Mapped[str] = mapped_column(String(32), nullable=False)
    phone_number_normalized: Mapped[str] = mapped_column(
        String(32), nullable=False, index=True
    )
    date_of_birth: Mapped[date] = mapped_column(Date, nullable=False)
    address: Mapped[str | None] = mapped_column(Text, nullable=True)
    id_photo_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    selfie_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    pin_hash: Mapped[str | None] = mapped_column(String(128), nullable=True)
    email: Mapped[str | None] = mapped_column(String(254))
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, server_default="pending", index=True
    )
    status_token_hash: Mapped[str] = mapped_column(
        String(128), nullable=False, unique=True, index=True
    )
    privacy_accepted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    terms_accepted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    submitted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    reviewed_by_user_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="RESTRICT")
    )
    review_notes: Mapped[str | None] = mapped_column(Text)
    rejection_reason: Mapped[str | None] = mapped_column(String(500))
    linked_borrower_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("borrowers.id", ondelete="RESTRICT"), index=True
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


class BorrowerRegistrationAudit(Base):
    """PII-minimal immutable security event for registration/account actions."""

    __tablename__ = "borrower_registration_audits"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    actor_user_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="RESTRICT"), index=True
    )
    action: Mapped[str] = mapped_column(String(50), nullable=False, index=True)
    target_type: Mapped[str] = mapped_column(String(40), nullable=False)
    target_id: Mapped[str] = mapped_column(String(36), nullable=False, index=True)
    metadata_json: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class BorrowerActivationCode(Base):
    """Cryptographically random 6-digit owner activation code for single-owner borrower activation."""

    __tablename__ = "borrower_activation_codes"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    borrower_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("borrowers.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    borrower_account_id: Mapped[str | None] = mapped_column(
        String(36),
        ForeignKey("borrower_accounts.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    code_hash: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, index=True
    )
    attempts: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    max_attempts: Mapped[int] = mapped_column(
        Integer, nullable=False, default=5, server_default="5"
    )
    used_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_by_user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    activated_device_id: Mapped[str | None] = mapped_column(String(120), nullable=True)
    activated_ip: Mapped[str | None] = mapped_column(String(45), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    borrower: Mapped["Borrower"] = relationship()
    created_by_user: Mapped["User"] = relationship()


class BorrowerLoanRequest(Base):
    """Separate entity for borrower-submitted loan requests awaiting owner review."""

    __tablename__ = "borrower_loan_requests"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    borrower_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("borrowers.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    requested_amount: Mapped[Decimal] = mapped_column(
        Numeric(18, 2), nullable=False
    )
    requested_term_months: Mapped[int] = mapped_column(Integer, nullable=False)
    purpose: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, server_default="submitted", index=True
    )
    owner_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_draft_loan_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("loans.id", ondelete="SET NULL"), nullable=True
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
    reviewed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    borrower: Mapped["Borrower"] = relationship()


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
    __table_args__ = (
        Index(
            "ix_borrower_devices_account_device_hash",
            "borrower_account_id",
            "device_identifier_hash",
        ),
    )

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
    device_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    model: Mapped[str | None] = mapped_column(String(100), nullable=True)
    app_version: Mapped[str | None] = mapped_column(String(50), nullable=True)
    push_token: Mapped[str | None] = mapped_column(String(512), nullable=True)
    push_token_updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    first_seen_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    last_seen_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    revoked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    is_trusted: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false"
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


class BorrowerPinReset(Base):
    """Owner-issued one-time code for borrower PIN reset."""

    __tablename__ = "borrower_pin_resets"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    borrower_account_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("borrower_accounts.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    code_hash: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, index=True
    )
    attempts: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    max_attempts: Mapped[int] = mapped_column(
        Integer, nullable=False, default=5, server_default="5"
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

    created_by_user: Mapped["User"] = relationship()


class BorrowerNotification(Base):
    """In-app notifications created for borrower account events (payments, reversals, etc.)."""

    __tablename__ = "borrower_notifications"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    borrower_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("borrowers.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    notification_type: Mapped[str] = mapped_column(
        String(50), nullable=False, default="payment_receipt", index=True
    )
    metadata_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    deduplication_key: Mapped[str | None] = mapped_column(
        String(120), nullable=True, unique=True, index=True
    )
    is_read: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default="false", index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), index=True
    )

    borrower: Mapped["Borrower"] = relationship()
