# Borrower Authentication & Security Specifications

## Overview
The Lending Nelson Borrower Portal provides an isolated, multi-factor, invite-backed authentication mechanism under `/api/v1/client/auth`.

## Authentication & Authorization Model

```
+-----------------------------------------------------------------------------------+
|                               OFFICER FLOW                                        |
| 1. Officer issues 6-digit activation code via POST /api/v1/borrowers/{id}/inv-code|
+-----------------------------------------------------------------------------------+
                                        |
                                        v
+-----------------------------------------------------------------------------------+
|                              BORROWER ACTIVATION                                  |
| 2. Borrower enters phone number & invitation code via POST /client/auth/request-otp|
| 3. Backend verifies code & dispatches SMS OTP                                    |
| 4. Borrower submits OTP via POST /client/auth/verify-otp                          |
| 5. Backend validates OTP, creates BorrowerAccount, issues JWT pair               |
+-----------------------------------------------------------------------------------+
```

## Core Security Controls
1. **Audience Boundary Enforcement (`aud: borrower-app`)**:
   - Access tokens issued to borrowers include `"aud": "borrower-app"` and `"account_type": "borrower"`.
   - The borrower dependency verifier (`require_active_borrower_account`) rejects officer tokens lacking the `borrower-app` audience.
   - The officer dependency verifier (`get_current_user`) rejects borrower tokens.

2. **Secret Hashing**:
   - Invitation codes, OTP codes, and refresh tokens are stored exclusively as HMAC-SHA256 hashes (`hash_secret()`).
   - Raw secrets are never saved in database records or logged.

3. **Rate Limiting & Attempts Lockout**:
   - OTP verification allows a maximum of 5 failed attempts per OTP before the record is invalidated.
   - Resend OTP requests enforce a 60-second cooldown period per phone number.

4. **Refresh Token Rotation & Automatic Reuse Detection**:
   - Refreshing an access token revokes the old refresh token immediately and issues a new refresh token.
   - If a revoked refresh token is presented, the backend invalidates all active sessions for the borrower account.

5. **Client Concurrency Protection**:
   - `AuthInterceptor` uses a `Completer<bool>` lock to queue parallel requests encountering 401 Unauthorized errors during token refresh, ensuring only a single HTTP `/client/auth/refresh` call is performed.
