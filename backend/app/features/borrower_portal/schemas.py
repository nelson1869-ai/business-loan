"""Pydantic schemas for borrower portal APIs."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class BaseSchema(BaseModel):
    """Base schema with camelCase alias and populate_by_name enabled."""

    model_config = ConfigDict(populate_by_name=True, from_attributes=True)


class OTPRequest(BaseSchema):
    """Payload to request an OTP code."""

    phone_number: str = Field(
        ..., alias="phoneNumber", description="Input phone number"
    )
    invitation_code: str | None = Field(
        None, alias="invitationCode", description="Optional activation code"
    )


class OTPRequestResponse(BaseSchema):
    """Generic response for OTP request."""

    message: str = "If the phone number is eligible, an OTP has been sent."
    resend_cooldown_seconds: int = Field(60, alias="resendCooldownSeconds")


class OTPVerifyRequest(BaseSchema):
    """Payload to verify an OTP and obtain tokens."""

    phone_number: str = Field(..., alias="phoneNumber")
    otp: str = Field(..., min_length=6, max_length=6)
    invitation_code: str | None = Field(None, alias="invitationCode")
    device_identifier: str = Field(..., alias="deviceIdentifier")
    platform: Literal["android", "ios", "web"] = "android"
    push_token: str | None = Field(None, alias="pushToken")


class BorrowerTokenResponse(BaseSchema):
    """JWT Token payload returned upon successful borrower verification."""

    access_token: str = Field(..., alias="accessToken")
    refresh_token: str = Field(..., alias="refreshToken")
    token_type: str = Field("Bearer", alias="tokenType")
    expires_in: int = Field(..., alias="expiresIn")
    borrower_account_id: str = Field(..., alias="borrowerAccountId")
    borrower_id: str = Field(..., alias="borrowerId")
    account_status: str = Field(..., alias="accountStatus")


class RefreshTokenRequest(BaseSchema):
    """Payload to request access token renewal using refresh token."""

    refresh_token: str = Field(..., alias="refreshToken")


class DeviceRegisterRequest(BaseSchema):
    """Payload to register or update device push tokens."""

    device_identifier: str = Field(..., alias="deviceIdentifier")
    platform: Literal["android", "ios", "web"] = "android"
    push_token: str | None = Field(None, alias="pushToken")


class DeviceResponse(BaseSchema):
    """Response returned for device registration or status."""

    id: str
    platform: str
    is_active: bool = Field(..., alias="isActive")
    last_seen_at: datetime = Field(..., alias="lastSeenAt")


class BorrowerProfileResponse(BaseSchema):
    """Profile payload returned for /client/me."""

    borrower_account_id: str = Field(..., alias="borrowerAccountId")
    borrower_id: str = Field(..., alias="borrowerId")
    first_name: str = Field(..., alias="firstName")
    last_name: str = Field(..., alias="lastName")
    phone_number: str = Field(..., alias="phoneNumber")
    account_status: str = Field(..., alias="accountStatus")
    created_at: datetime = Field(..., alias="createdAt")


class ClientInvitationRequest(BaseSchema):
    """Officer request to issue a borrower portal invitation code."""

    expires_in_hours: int = Field(72, alias="expiresInHours", ge=1, le=720)


class ClientInvitationResponse(BaseSchema):
    """Response containing officer-issued client invitation details."""

    id: str
    borrower_id: str = Field(..., alias="borrowerId")
    invitation_code: str = Field(..., alias="invitationCode")
    expires_at: datetime = Field(..., alias="expiresAt")
    created_at: datetime = Field(..., alias="createdAt")
