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

## Data Seeding Tool

Populate the database with sample borrowers, active loans, overdue loans, paid loans, and today's collection items:

```powershell
$env:SEED_USERNAME="officer1"; $env:SEED_PASSWORD="password123"; dart run tool/seed_data.dart --reset
```

## Python backend

The backend provides JWT authentication, borrower CRUD, loan workflows, exact payment allocation, immutable reversals, receipt and statement projections, dashboard and financial reports, PostgreSQL persistence, and offline mutation replay.

See [backend/README.md](backend/README.md) for PostgreSQL setup, migrations, first-user creation, and server commands.

Major API areas include:

```text
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

Use Swagger or `/openapi.json` for the exact methods, fields, aliases, enums, and status codes. Do not point Flutter at an API exposing `/api/v1/auth/login`; this application uses the access/refresh-token contract above.

## Security

- Borrower PII is encrypted in device-local SQLite.
- Offline queue payloads are encrypted at rest.
- Backend audit records redact names, national IDs, and phone numbers.
- JWTs and encryption keys are stored using secure storage.
- Secrets belong in `backend/.env`, which must never be committed.
