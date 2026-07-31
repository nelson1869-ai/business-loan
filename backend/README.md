# Lending Nelson FastAPI Backend

Async financial backend for the Lending Nelson Flutter application. It uses FastAPI, SQLAlchemy 2, PostgreSQL, Alembic, and Pydantic v2.

Application composition is intentionally incremental: `app/main.py` remains the
factory, router registration lives in `app/api/router.py`, health endpoints live
in `app/health/router.py`, and defensive HTTP controls live in
`app/middleware/`. Login and Admin Assistant throttling share a Redis-first
limiter with a bounded process-local fallback.

Offline mutations are accepted only through `/api/v1/sync/drain`. Each replayed
mutation and its idempotency receipt are committed atomically. New replay
operations require endpoint, method, payload, authorization, rollback, and
idempotency tests.

The backend is the source of truth for loan schedules, payment allocation, balances, receipts, statements, dashboard totals, and financial reports. Flutter clients should display these results rather than recalculate them.

Run the commands below from `D:\Development\lending_nelson\backend` in PowerShell.

## Requirements

- Python 3.12 or newer
```

It should resolve to `backend\.venv\Scripts\python.exe`.

`bcrypt` is pinned to 4.3.0 because Passlib 1.7.4 is incompatible with bcrypt 5.0's password-length backend probe.

## 2. Configure PostgreSQL

Create the development database if it does not already exist:

```powershell
psql -U postgres -c "CREATE DATABASE lending_nelson;"
```

Create the local environment file:

```powershell
Copy-Item .env.example .env
```

Configure at least:

```dotenv
APP_ENV=development
DATABASE_URL=postgresql+asyncpg://postgres:your-password@localhost:5432/lending_nelson
JWT_SECRET_KEY=replace-with-a-random-secret-of-at-least-32-characters
```

Generate a development JWT secret:

```powershell
py -c "import secrets; print(secrets.token_urlsafe(48))"
```

Never commit `.env`, database passwords, JWT secrets, or generated tokens.

## 3. Run database migrations

```powershell
.\.venv\Scripts\python.exe -m alembic upgrade head
```

The migrations create the authentication, borrower, audit, loan, installment, lifecycle, payment, and payment-allocation structures required by the API.

Check that the ORM metadata and migration head agree:

```powershell
.\.venv\Scripts\python.exe -m alembic check
```

## 4. Create a development user

Create an officer account:

```powershell
.\.venv\Scripts\python.exe -m app.bootstrap <your-username> --role officer
```

The command prompts for the password and confirmation without displaying them. Passwords must contain 8ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ72 UTF-8 bytes.

Reset an existing user's password:

```powershell
.\.venv\Scripts\python.exe -m app.bootstrap <your-username> --reset-password
```

Enter the new password only at the secure prompt. Do not place it directly in a PowerShell command.


```text
username: <your-username>
password: <set-a-strong-password>
```

This credential is for disposable development environments only. Never use it in production.

## 5. Start the API

Local development:

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Useful URLs:

- Health: `http://127.0.0.1:8000/health`
- Swagger UI: `http://127.0.0.1:8000/docs`
- ReDoc: `http://127.0.0.1:8000/redoc`
- OpenAPI: `http://127.0.0.1:8000/openapi.json`

## 6. API capabilities

All protected endpoints require `Authorization: Bearer <access-token>`.

| Area | Endpoints and behavior |
| --- | --- |
| Authentication | `POST /api/v1/auth/token`, `POST /api/v1/auth/refresh` |
| Borrowers | Create, list, retrieve, update, and soft-delete under `/api/v1/borrowers` |
| Loans | Active creation, draft creation, list, detail, filtering, and paginated results under `/api/v1/loans` |
| Workflow | `POST /api/v1/loans/{loanId}/workflow/{action}` for approve, disburse, activate, complete, default, cancel, and close |
| Payments | Preview, confirm, list, paginate, and reverse under `/api/v1/loans/{loanId}/payments` |
| Receipt | `GET /api/v1/payments/{paymentId}/receipt` |
| Statement | `GET /api/v1/loans/{loanId}/statement` |
| Dashboard | `GET /api/v1/dashboard?asOf=YYYY-MM-DD` |
| Financial report | `GET /api/v1/reports/financial?dateFrom=YYYY-MM-DD&dateTo=YYYY-MM-DD` |
| Offline sync | `POST /api/v1/sync/drain` |

The OpenAPI document is the authoritative contract for request fields, response fields, enums, aliases, and status codes.

## 7. Financial rules

- Financial values use `Decimal`; avoid binary floating-point arithmetic for currency.
- Payment allocations and running balances are calculated in backend services.
- Receipts and statements are projections of persisted ledger data.
- Request IDs provide idempotency for loan creation, payment creation, and payment reversal.
- Reusing a request ID with conflicting data returns `409 Conflict`.
- Reversals append ledger history; they do not delete the original payment.
- Paginated endpoints use stable ordering and return `items`, `total`, `offset`, and `limit`.
- Valid pagination requires `offset >= 0` and `1 <= limit <= 200`.

## 8. Run backend checks

```

Last verified result:

```text
Compile: passed
Backend tests: 63 executed, 60 passed, 3 skipped, 0 failed
Alembic: no new upgrade operations detected
```

If an embedded Windows Python distribution does not add the current backend directory to `sys.path`, use a standard `py -m venv .venv` environment. Do not change application imports merely to hide an incorrectly constructed virtual environment.



## 10. Connect Flutter

Windows desktop or web on the development computer:

```powershell
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Android emulator:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

For a physical Android device, bind Uvicorn to the LAN and use the computer's LAN IP:

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Allow port 8000 through Windows Firewall only on trusted development networks.

## 12. Troubleshooting

- `401 Unauthorized`: log in again and use the returned access token.
- `404 Not Found`: confirm the resource ID and verify development cleanup has not removed it.
- `409 Conflict`: inspect idempotency-key reuse, workflow state, duplicate national IDs, or reversal state.
- `422 Unprocessable Content`: check the OpenAPI schema, camelCase aliases, UUIDs, date formats, enum values, and pagination bounds.
- `500 Internal Server Error`: inspect the Uvicorn traceback and PostgreSQL connection; do not suppress the error by weakening validation.
- PostgreSQL connection failure: verify the service, database name, port, user, password, and `DATABASE_URL` driver (`postgresql+asyncpg`).

One current workflow limitation is that a successful `complete` transition cannot naturally be produced after payoff because full payoff changes the loan directly to `Paid`. Completing a loan that still has a balance correctly returns `409 Conflict`.
