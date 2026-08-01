# Borrower Portal API Documentation

## Overview
All endpoints for borrower self-service, authentication, and device management are prefixed with `/api/v1/client`.

## Endpoints

### 1. Request SMS OTP
`POST /api/v1/client/auth/request-otp`
- **Request Body**:
  ```json
  {
    "phoneNumber": "09179876543",
    "invitationCode": "A3X9K2"
  }
  ```
- **Response (200 OK)**:
  ```json
  {
    "message": "OTP delivered if number is eligible",
    "resendCooldownSeconds": 60
  }
  ```

### 2. Verify OTP & Obtain Tokens
`POST /api/v1/client/auth/verify-otp`
- **Request Body**:
  ```json
  {
    "phoneNumber": "09179876543",
    "otp": "123456",
    "invitationCode": "A3X9K2",
    "deviceIdentifier": "android-device-uuid",
    "platform": "android"
  }
  ```
- **Response (200 OK)**:
  ```json
  {
    "accessToken": "<jwt-access-token>",
    "refreshToken": "<raw-refresh-token>",
    "tokenType": "bearer",
    "expiresInSeconds": 900,
    "borrowerAccountId": "<account-uuid>",
    "borrowerId": "<borrower-uuid>",
    "accountStatus": "active"
  }
  ```

### 3. Refresh Access Token
`POST /api/v1/client/auth/refresh`
- **Request Body**:
  ```json
  {
    "refreshToken": "<raw-refresh-token>"
  }
  ```
- **Response (200 OK)**: Token pair response with rotated refresh token.

### 4. Logout Session
`POST /api/v1/client/auth/logout`
- **Headers**: `Authorization: Bearer <access-token>`
- **Request Body**: `{"refreshToken": "<refresh-token>"}`
- **Response**: `204 No Content`

### 5. Get Borrower Profile
`GET /api/v1/client/me`
- **Headers**: `Authorization: Bearer <access-token>`
- **Response (200 OK)**:
  ```json
  {
    "borrowerAccountId": "<account-uuid>",
    "borrowerId": "<borrower-uuid>",
    "firstName": "Maria",
    "lastName": "Santos",
    "phoneNumber": "+639179876543",
    "accountStatus": "active"
  }
  ```

### 6. Register/Update Borrower Device
`POST /api/v1/client/devices`
- **Headers**: `Authorization: Bearer <access-token>`
- **Response (200 OK)**:
  ```json
  {
    "id": "<device-uuid>",
    "borrowerAccountId": "<account-uuid>",
    "platform": "android",
    "isActive": true,
    "lastSeenAt": "2026-08-01T12:00:00Z"
  }
  ```

### 7. Officer Issue Client Invitation
`POST /api/v1/borrowers/{borrower_id}/client-invitation`
- **Headers**: `Authorization: Bearer <officer-access-token>`
- **Response (201 Created)**:
  ```json
  {
    "borrowerId": "<borrower-uuid>",
    "invitationCode": "A3X9K2",
    "expiresAt": "2026-08-04T12:00:00Z"
  }
  ```
