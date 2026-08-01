# Borrower Portal Client API Specification

All borrower portal endpoints are registered under prefix `/api/v1/client`.

## Endpoints Summary

### Authentication

- `POST /api/v1/client/auth/request-otp`: Request an SMS OTP for a mobile number.
- `POST /api/v1/client/auth/verify-otp`: Verify OTP code and activation invitation to obtain JWT tokens.
- `POST /api/v1/client/auth/refresh`: Rotate refresh token and obtain new access token.
- `POST /api/v1/client/auth/logout`: Revoke active refresh token.

### Borrower Identity & Profile

- `GET /api/v1/client/me`: Return authenticated borrower profile details.

### Device Management

- `POST /api/v1/client/devices`: Register or update push notification tokens.
- `DELETE /api/v1/client/devices/{deviceId}`: Deactivate registered device.

### Officer Invitation Endpoint

- `POST /api/v1/borrowers/{borrowerId}/client-invitation`: Officer endpoint to generate a 6-digit client activation code.
