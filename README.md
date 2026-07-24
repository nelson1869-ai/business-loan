# Lending Nelson

Student resources: [Documentation Index](docs/README.md) |
[Student Guide](docs/guides/STUDENT_GUIDE.md) |
[Development Log](docs/history/DEVELOPMENT_LOG.md) |
[Product Roadmap](docs/roadmap/README.md) |
[Project TODO](TODO.md) |
[Quick Start](docs/QUICK_START.md) |
[Data Flows](docs/architecture/DATA_FLOWS.md)

Lending Nelson is an offline-capable microfinance application built with Flutter and a FastAPI/PostgreSQL backend.

## Project structure

```text
lib/       Flutter application
backend/   FastAPI backend and Alembic migrations
postman/   Complete API regression collection
docs/      Architecture, guides, domain rules, roadmap, and history
tool/      Development data utilities
test/      Flutter unit and widget tests
```

## Start local development

The root launcher starts FastAPI, checks backend health, and runs Flutter with the selected target URL:

```powershell
.\start.ps1 -Target android
```

Or target a physical Android phone wirelessly:

```powershell
.\start-phone.ps1
```

or via Bash / Git Bash:

```bash
./start-phone.sh
```

Other examples:

```powershell
.\start.ps1 -Target localhost
.\start.ps1 -Target 192.168.1.50
.\start.ps1 -Target android -Port 8001
```

The launcher force-stops an existing process using the selected port. Use a different port when that process must remain running. See [Quick Start](docs/QUICK_START.md) for manual startup and target details.

## Health Monitoring & Connectivity

The backend provides hardened liveness and readiness endpoints:

- `GET /health/live`: Fast process check confirming FastAPI is alive (no database queries).
- `GET /health/ready`: Database connectivity check via `SELECT 1`. Returns HTTP 200 `ready` or HTTP 503 `unavailable` without exposing sensitive credentials or stack traces.
- `GET /health`: Backward-compatible lightweight service ping.

Flutter tracks four discrete network and server states:
1. `offline`: Physical device interface has no internet/Wi-Fi connection.
2. `networkAvailable`: Physical connection present, probing backend health.
3. `serverUnavailable`: Physical network available, but backend is unreachable or returning HTTP 503.
4. `serverReady`: Backend is verified reachable and database is connected.

## Offline Synchronization & Diagnostics

- **Reactive Sync Counters:** Pending counts update real-time upon enqueue, retry, and drain.
- **SQLite Queue Diagnostics:** Schema version 5 tracks `status` (`pending`, `syncing`, `retryableFailed`, `permanentlyFailed`, `conflict`), `retry_count`, `last_attempt_at`, `last_error_code`, `last_error_message`, `next_retry_at`, and `server_resource_id`.
- **Automatic Crash Recovery:** Stale `syncing` queue records automatically reset to `pending` on startup.
- **Bounded Exponential Backoff:** Re-attempts calculate retry delays automatically.
- **Diagnostics Screen:** Accessible under Dev Tools / Settings to inspect, retry, copy safe summaries, or remove queue items.

## Development & Production Security

- Admin reset (`/api/v1/admin/reset`) and sample seed (`/api/v1/admin/seed`) endpoints are strictly disabled when `APP_ENV=production`.
- Production rejects wildcard CORS origins (`*`) and requires strong, non-placeholder JWT secret keys.
- Borrower PII and offline queue payloads are encrypted at rest using AES-GCM.
- Backend audit logs redact borrower names, national IDs, phone numbers, passwords, and JWT tokens.

## Flutter app

Install packages and run the app:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Use `10.0.2.2` from the Android emulator. Use `http://localhost:8000` for Windows or web development.

Run checks:

```powershell
dart format lib test
flutter analyze
flutter test
```

## Python backend

Major API routes include:

```text
GET    /health/live
GET    /health/ready
POST   /api/v1/auth/token
POST   /api/v1/auth/refresh
*      /api/v1/borrowers
*      /api/v1/loans
*      /api/v1/loans/{loanId}/workflow/{action}
*      /api/v1/loans/{loanId}/payments
GET    /api/v1/payments/{paymentId}/receipt
GET    /api/v1/loans/{loanId}/statement
GET    /api/v1/dashboard
GET    /api/v1/reports/financial
POST   /api/v1/sync/drain
```

Run backend checks:

```powershell
Set-Location backend
$env:PYTHONPATH="."; .\.venv\Scripts\python.exe -m unittest discover -s tests -t .
.\.venv\Scripts\python.exe -m alembic check
```

Run Postman API regression suite:

```powershell
npx --yes newman run postman\lending-nelson-api.json
```
