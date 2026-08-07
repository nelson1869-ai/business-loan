"""Pydantic schemas for borrower portal APIs."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class BaseSchema(BaseModel):
    """Base schema with camelCase alias and populate_by_name enabled."""

    model_config = ConfigDict(populate_by_name=True, from_attributes=True)





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
    """Payload to register or update device details."""

    device_identifier: str = Field(..., alias="deviceIdentifier")
    platform: Literal["android", "ios", "web"] = "android"
    device_name: str | None = Field(None, alias="deviceName")
    model: str | None = Field(None)
    app_version: str | None = Field(None, alias="appVersion")
    push_token: str | None = Field(None, alias="pushToken")


class DeviceResponse(BaseSchema):
    """Response returned for device registration or status."""

    id: str
    platform: str
    device_name: str | None = Field(None, alias="deviceName")
    model: str | None = Field(None)
    app_version: str | None = Field(None, alias="appVersion")
    is_trusted: bool = Field(False, alias="isTrusted")
    is_active: bool = Field(True, alias="isActive")
    first_seen_at: datetime | None = Field(None, alias="firstSeenAt")
    last_seen_at: datetime = Field(..., alias="lastSeenAt")
    revoked_at: datetime | None = Field(None, alias="revokedAt")


class ConfirmPINRequest(BaseSchema):
    """Payload to confirm PIN after activation."""

    pin: str = Field(..., alias="pin", min_length=4, max_length=128)


class ForgotPINRequest(BaseSchema):
    """Payload for borrower to request PIN reset."""

    phone_number: str = Field(..., alias="phoneNumber")


class ResetPINRequest(BaseSchema):
    """Payload to reset PIN using owner-issued reset code."""

    phone_number: str = Field(..., alias="phoneNumber")
    reset_code: str = Field(..., alias="resetCode", min_length=6, max_length=6)
    new_pin: str = Field(..., alias="newPin", min_length=4, max_length=128)


class IssueResetCodeResponse(BaseSchema):
    """Response for owner issuing PIN reset code."""

    account_id: str = Field(..., alias="accountId")
    reset_code: str = Field(..., alias="resetCode")
    expires_at: datetime = Field(..., alias="expiresAt")


class BorrowerProfileResponse(BaseSchema):
    """Profile payload returned for /client/me."""

    borrower_account_id: str = Field(..., alias="borrowerAccountId")
    borrower_id: str = Field(..., alias="borrowerId")
    first_name: str = Field(..., alias="firstName")
    last_name: str = Field(..., alias="lastName")
    phone_number: str = Field(..., alias="phoneNumber")
    account_status: str = Field(..., alias="accountStatus")
    created_at: datetime = Field(..., alias="createdAt")



class BorrowerRegistrationSubmitRequest(BaseSchema):
    """Borrower public sign-up registration request payload."""

    first_name: str = Field(..., alias="firstName", min_length=1, max_length=100)
    last_name: str = Field(..., alias="lastName", min_length=1, max_length=100)
    phone_number: str = Field(..., alias="phoneNumber", min_length=7, max_length=32)
    address: str = Field(..., alias="address", min_length=2, max_length=500)
    date_of_birth: str = Field(..., alias="dateOfBirth")
    national_id: str = Field(..., alias="nationalId", min_length=1, max_length=100)
    id_photo_url: str | None = Field(None, alias="idPhotoUrl")
    selfie_url: str | None = Field(None, alias="selfieUrl")
    pin_or_password: str = Field(..., alias="pinOrPassword", min_length=4, max_length=128)


class BorrowerActivationRequest(BaseSchema):
    """Payload for borrower to redeem 6-digit owner activation code and optionally create PIN."""

    phone_number: str = Field(..., alias="phoneNumber")
    activation_code: str = Field(..., alias="activationCode", min_length=6, max_length=6)
    device_identifier: str = Field(..., alias="deviceIdentifier")
    platform: Literal["android", "ios", "web"] = "android"
    push_token: str | None = Field(None, alias="pushToken")
    new_pin: str | None = Field(None, alias="newPin", min_length=4, max_length=128)
    confirm_pin: str | None = Field(None, alias="confirmPin", min_length=4, max_length=128)


class EnableAppAccessResponse(BaseSchema):
    """Response returned to Owner when enabling app access for an existing borrower (returns raw activation code once)."""

    borrower_id: str = Field(..., alias="borrowerId")
    borrower_account_id: str = Field(..., alias="borrowerAccountId")
    account_status: str = Field(..., alias="accountStatus")
    activation_code: str = Field(..., alias="activationCode")
    expires_at: datetime = Field(..., alias="expiresAt")


class BorrowerAppAccessStatusResponse(BaseSchema):
    """Status payload returned for Owner app access query. NEVER includes raw activation code."""

    has_account: bool = Field(..., alias="hasAccount")
    account_id: str | None = Field(None, alias="accountId")
    account_status: str | None = Field(None, alias="accountStatus")
    phone_number: str | None = Field(None, alias="phoneNumber")
    activation_pending: bool = Field(False, alias="activationPending")
    activation_expires_at: datetime | None = Field(None, alias="activationExpiresAt")
    trusted_devices_count: int = Field(0, alias="trustedDevicesCount")
    last_login_at: datetime | None = Field(None, alias="lastLoginAt")
    can_regenerate_activation_code: bool = Field(False, alias="canRegenerateActivationCode")


class BorrowerPINLoginRequest(BaseSchema):
    """Payload for activated borrower PIN/password authentication."""

    phone_number: str = Field(..., alias="phoneNumber")
    pin_or_password: str = Field(..., alias="pinOrPassword")
    device_identifier: str = Field(..., alias="deviceIdentifier")


class BorrowerRegistrationItemResponse(BaseSchema):
    """Item for owner registration review list."""

    id: str
    first_name: str = Field(..., alias="firstName")
    last_name: str = Field(..., alias="lastName")
    phone_number: str = Field(..., alias="phoneNumber")
    address: str | None = None
    date_of_birth: str = Field(..., alias="dateOfBirth")
    national_id: str | None = Field(None, alias="nationalId")
    id_photo_url: str | None = Field(None, alias="idPhotoUrl")
    selfie_url: str | None = Field(None, alias="selfieUrl")
    status: str
    rejection_reason: str | None = Field(None, alias="rejectionReason")
    submitted_at: datetime = Field(..., alias="submittedAt")


class OwnerApproveRegistrationResponse(BaseSchema):
    """Response returned to Owner when approving a registration."""

    registration_id: str = Field(..., alias="registrationId")
    borrower_id: str = Field(..., alias="borrowerId")
    borrower_account_id: str = Field(..., alias="borrowerAccountId")
    activation_code: str = Field(..., alias="activationCode")
    expires_at: datetime = Field(..., alias="expiresAt")


RequestedPaymentFrequency = Literal["monthly", "twice_a_month"]
RequestedRepaymentStructure = Literal["principal_plus_interest", "interest_only"]


class BorrowerLoanRequestSubmit(BaseSchema):
    """Payload for borrower to submit a new loan request."""

    requested_amount: str = Field(..., alias="requestedAmount")
    requested_term_months: int = Field(..., alias="requestedTermMonths", ge=1, le=120)
    requested_payment_frequency: RequestedPaymentFrequency = Field(
        "monthly", alias="requestedPaymentFrequency"
    )
    requested_repayment_structure: RequestedRepaymentStructure = Field(
        "principal_plus_interest", alias="requestedRepaymentStructure"
    )
    purpose: str | None = Field(None, alias="purpose", max_length=500)


class BorrowerLoanRequestResponse(BaseSchema):
    """Loan request response object."""

    id: str
    borrower_id: str = Field(..., alias="borrowerId")
    requested_amount: str = Field(..., alias="requestedAmount")
    requested_term_months: int = Field(..., alias="requestedTermMonths")
    requested_payment_frequency: RequestedPaymentFrequency = Field(
        "monthly", alias="requestedPaymentFrequency"
    )
    requested_repayment_structure: RequestedRepaymentStructure = Field(
        "principal_plus_interest", alias="requestedRepaymentStructure"
    )
    purpose: str | None = None
    status: str
    owner_notes: str | None = Field(None, alias="ownerNotes")
    created_draft_loan_id: str | None = Field(None, alias="createdDraftLoanId")
    created_at: datetime = Field(..., alias="createdAt")


class ReviewBorrowerLoanRequestPayload(BaseSchema):
    """Owner review action on a borrower loan request."""

    action: Literal["approve", "decline"]
    owner_notes: str | None = Field(None, alias="ownerNotes")
