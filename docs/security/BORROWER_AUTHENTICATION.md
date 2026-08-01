# Borrower Authentication & Identity Security

## Overview

Borrower portal security enforces a dedicated identity boundary, cryptographic OTP verification, secure account linking, token rotation, and generic privacy responses.

## Identity Models

1. **`borrower_accounts`**: Dedicated portal identity linked 1:1 to an officer-managed `Borrower` record.
2. **`borrower_invitations`**: Officer-issued 6-digit activation code required for initial account setup (`POST /api/v1/borrowers/{borrowerId}/client-invitation`).
3. **`borrower_otps`**: Cryptographically secure 6-digit OTP codes hashed with SHA-256 before storage.
4. **`borrower_refresh_tokens`**: Hashed refresh tokens stored in database with automatic reuse detection and revocation.
5. **`borrower_devices`**: Device tracking and push notification token registry (`/api/v1/client/devices`).

## Security Controls

- **Token Audience Boundary**: Borrower access tokens include `aud: borrower-app` and `account_type: borrower`. Officer access tokens are rejected on `/api/v1/client/*`, and borrower tokens are rejected on `/api/v1/loans`.
- **Non-Enumerating Public Responses**: `/api/v1/client/auth/request-otp` returns a generic success response regardless of whether the phone number exists in the system.
- **Refresh Token Rotation**: Each token refresh revokes the old refresh token and issues a new pair. Attempting to reuse a revoked refresh token immediately revokes all active sessions for that account.
- **Rate Limiting & Cooldowns**: Resend cooldowns (60s) and single-use maximum verification attempts (5 attempts) are enforced.
