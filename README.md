# Lending Nelson

Lending Nelson is an offline-first microfinance lending platform featuring a Flutter Android application and a FastAPI/PostgreSQL backend.

Detailed local-write, queue-lifecycle, recovery, and manual server-off
instructions are in
[docs/architecture/OFFLINE_SYNC.md](docs/architecture/OFFLINE_SYNC.md).

## Offline-First Architecture

The application is engineered to operate seamlessly even when the backend server is turned off, disconnected, or unreachable. All core lending operations—creating borrowers, loans, loan schedules, repayments, collections, notes, guarantors, emergency contacts, and documents—succeed immediately on the mobile device.

### Key Components

- **Local SQLite Database (`v6`)**: Normalized local storage for borrowers, loans, schedules, repayments, guarantors, emergency contacts, notes, documents, sync queue, conflicts, and metadata.
- **Offline Financial Calculator (`LoanCalculator`)**: Pure Dart loan calculator with exact integer cent precision (`ROUND_HALF_UP`) providing 100% calculation parity with the backend (`loan_calculator.py`).
- **Durable Sync Outbox Queue**: Outbox pattern in SQLite with entity dependency graph ordering (Borrower -> Loan -> Repayment) and exponential backoff retry.
- **Server Idempotency**: Client-generated UUIDs and idempotency keys (`request_id`) prevent duplicate records during retries or re-synchronization.
- **Reachability & Connectivity Engine**: Fast `/health/ready` probing with 2-second timeout to differentiate between physical network connectivity and actual backend server availability.
- **Sync & Conflict Management UI**: Visual status badges, persistent status banners, and a dedicated Sync Management screen (`/sync-management`) to inspect pending items, failed operations, conflicts, and manually trigger synchronization.
- **PII Encryption & Security**: Borrower sensitive PII is encrypted at rest in local SQLite using AES encryption and masked in application logs (`[REDACTED]`).

## Repository Structure

- `lib/`: Flutter mobile application (Clean Architecture: Presentation, Domain, Data)
- `backend/app/`: Authenticated FastAPI backend API
- `backend/alembic/`: PostgreSQL migrations
- `docs/`: Architecture, deployment, domain, and API documentation
- `test/` and `backend/tests/`: Automated unit, widget, and integration test suites

## Verification & Testing

Run all quality checks and test suites:

```powershell
# 1. Flutter Analysis & Formatting
flutter analyze
dart format --output=none --set-exit-if-changed lib test

# 2. Flutter Unit & Widget Tests (including LoanCalculator parity)
flutter test

# 3. Backend Test Suite
Set-Location backend
$env:PYTHONPATH="."; .\.venv\Scripts\python.exe -c "import sys; sys.path.insert(0, '.'); import unittest; unittest.main(module=None, argv=['', 'discover', '-s', 'tests'])"
```

## Manual Verification Procedure (Server-Off Testing)

1. Start the backend server (`uvicorn app.main:app`).
2. Log into the Android application.
3. Completely stop the backend server process on the PC.
4. Create a new borrower on the Android phone.
5. Create a loan for that borrower and inspect the generated installment schedule.
6. Record a repayment / collection.
7. Close and reopen the app (and restart the phone/emulator); confirm all records remain intact.
8. Restart the backend server process on the PC.
9. Tap "Sync Now" in the application (or wait for auto-sync).
10. Confirm all records move to `Synced` status and exactly one copy of each record exists on the server.

See [docs/README.md](docs/README.md), [backend/README.md](backend/README.md), and [docs/domain/LOAN_AND_PAYMENT_RULES.md](docs/domain/LOAN_AND_PAYMENT_RULES.md).
