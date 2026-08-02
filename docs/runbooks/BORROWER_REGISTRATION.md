# Borrower Registration Runbook

This document describes the complete flow for registering a new borrower on the
Lending Nelson Borrower Portal, from officer invitation to first login. It covers
development, testing, and production scenarios.

---

## Prerequisites

| Requirement | Details |
| --- | --- |
| Officer account | A user with `role = officer` or `role = admin` in the `users` table |
| Borrower record | A `borrowers` row already created by the officer in the Officer App |
| Backend running | FastAPI on `http://localhost:8000` (dev) or `https://your-domain` (prod) |
| Borrower App installed | Android debug or release APK on device or emulator |

---

## Architecture Overview

Borrowers **cannot self-register**. The flow is officer-initiated:

```
Officer App           Backend              Borrower App
    |                    |                      |
    |-- POST /invitations -->                   |
    |<-- invitation_code --                     |
    |                    |                      |
    | (shares code       |                      |
    |  with borrower     |                      |
    |  out-of-band)      |                      |
    |                    |<-- POST /auth/request-otp (phone + code)
    |                    |-- OTP issued -------->|
    |                    |<-- POST /auth/verify-otp (phone + otp)
    |                    |-- access_token + refresh_token -->
```

The invitation code is a **one-time 6-digit code** that links the borrower record
to the phone number. It is hashed immediately on storage and is only available as
plaintext in the API response at the moment of creation.

The OTP is a **5-minute one-time code** sent via SMS (production) or logged to
the backend console (development). It is also hashed on storage.

---

## Step 1 — Obtain an Officer Access Token

### Via the Officer Flutter App

Log in normally. The app manages the token lifecycle automatically.

### Via API (development / testing)

```powershell
# PowerShell
$response = Invoke-RestMethod `
  -Uri "http://localhost:8000/api/v1/auth/token" `
  -Method POST `
  -ContentType "application/x-www-form-urlencoded" `
  -Body "username=YOUR_OFFICER_USERNAME&password=YOUR_PASSWORD"

$token = $response.access_token
```

> **Never commit officer credentials.** Use environment variables or a secrets
> manager in CI and production scripts.

---

## Step 2 — Find the Borrower ID

The borrower must already exist as a record created by the officer.

```powershell
# List recent borrowers
Invoke-RestMethod `
  -Uri "http://localhost:8000/api/v1/borrowers?limit=10" `
  -Headers @{ Authorization = "Bearer $token" }
```

Or query the database directly (development only):

```powershell
$env:PGPASSWORD = "YOUR_DB_PASSWORD"
& "D:\Program Files\PostgreSQL\18\bin\psql.exe" `
  -h localhost -p 5434 -U postgres -d lending_nelson `
  -c "SELECT id, first_name, last_name, phone, status FROM borrowers ORDER BY created_at DESC LIMIT 10;"
```

---

## Step 3 — Issue an Invitation

```powershell
$borrowerId = "paste-borrower-uuid-here"
$phoneNumber = "09XXXXXXXXX"   # Borrower's registered phone number (local PH format)

$body = @{
  borrower_id  = $borrowerId
  phone_number = $phoneNumber
} | ConvertTo-Json

$invitation = Invoke-RestMethod `
  -Uri "http://localhost:8000/api/v1/borrower-portal/invitations" `
  -Method POST `
  -Headers @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" } `
  -Body $body

# Display the plaintext code — this is the ONLY time it is readable
Write-Host "Invitation code: $($invitation.invitation_code)"
Write-Host "Expires at:      $($invitation.expires_at)"
```

**Important:**
- The `invitation_code` in the response is the **only time the plaintext value is
  available**. It is hashed immediately in the database.
- The code expires after the configured TTL (default: 48 hours).
- Each borrower can have only one active (unused) invitation at a time.
- Give the 6-digit code to the borrower securely (in person, via call, etc.).

---

## Step 4 — Borrower First Login in the App

1. Open the **Lending Nelson Borrower Portal** app.
2. Enter the **Mobile Number** (e.g. `09171234567`).
3. Enter the **Client Activation Code** — the 6-digit code from Step 3.
4. Tap **Request OTP Code**.
5. Enter the OTP received via SMS.
6. The borrower account is created and the dashboard is shown.

> **Development:** SMS is not wired. Read the OTP from the backend console output
> (see Step 5 below).

---

## Step 5 — Read the OTP in Development

Since SMS is not sent in development, the OTP is printed in the backend log.

### From the running terminal

Look for a line like:

```
INFO:app.features.borrower_portal.service:OTP issued phone=+639XXXXXXXXX
```

The log line includes the OTP value for development convenience.

### From the database (metadata only — code is hashed)

```powershell
$env:PGPASSWORD = "YOUR_DB_PASSWORD"
& "D:\Program Files\PostgreSQL\18\bin\psql.exe" `
  -h localhost -p 5434 -U postgres -d lending_nelson `
  -c "SELECT phone_number_normalized, expires_at, used_at, attempts, created_at FROM borrower_otps ORDER BY created_at DESC LIMIT 5;"
```

The `otp_code_hash` column stores only a bcrypt hash — the plaintext is never
stored. Use the backend console log to retrieve the code.

---

## Step 6 — Verify Registration Succeeded

```powershell
$env:PGPASSWORD = "YOUR_DB_PASSWORD"
& "D:\Program Files\PostgreSQL\18\bin\psql.exe" `
  -h localhost -p 5434 -U postgres -d lending_nelson `
  -c "
    SELECT
      b.first_name,
      b.last_name,
      b.phone,
      b.status,
      a.id            AS account_id,
      a.created_at    AS account_created,
      i.used_at       AS invitation_used
    FROM borrowers b
    JOIN borrower_accounts a ON a.borrower_id = b.id
    JOIN borrower_invitations i ON i.borrower_id = b.id
    ORDER BY a.created_at DESC
    LIMIT 10;
  "
```

A row appearing in `borrower_accounts` confirms the borrower has successfully
registered.

---

## Returning Borrower Login

Once registered, the **Client Activation Code** field is left empty. The borrower
enters only their phone number and taps **Request OTP Code**.

```
Phone Number → [Request OTP] → Enter OTP → Logged in
```

Refresh tokens rotate automatically. The session remains valid for 7 days of
inactivity before requiring re-login.

---

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `400 Invalid or expired invitation code` | Code already used, expired, or wrong digits | Issue a new invitation from the Officer App |
| `400 Phone number does not match invitation` | Phone entered in app differs from the one on the invitation | Confirm the phone number with the borrower |
| `400 OTP expired` | 5-minute OTP window passed | Tap **Request OTP Code** again to generate a new one |
| `400 Too many OTP attempts` | 5 failed OTP attempts | Wait for the lockout to expire, then request a new OTP |
| `409 Active account already exists` | Borrower is already registered | Use the returning-borrower login flow (no code needed) |
| OTP not received | SMS not configured in dev | Check the backend console for the plaintext OTP |

---

## Security Notes

- Invitation codes and OTP codes are **never stored in plaintext**. Both are
  hashed (bcrypt) in the database immediately on creation.
- Device identifiers are hashed (SHA-256) before storage.
- Borrower PII (name, phone, ID) is encrypted at rest in local storage.
- The borrower portal routes (`/api/v1/client/*`) are fully isolated from officer
  routes and enforce ownership at every endpoint.
- Refresh tokens are single-use with rotation. Reuse of a consumed token triggers
  immediate family revocation.

---

## Related Documentation

- [Borrower Portal API reference](../api/BORROWER_PORTAL_API.md)
- [System architecture overview](../architecture/SYSTEM_OVERVIEW.md)
- [Local Wi-Fi testing setup](../local_wifi_testing/README.md)
- [Backend environment configuration](../../backend/README.md)
