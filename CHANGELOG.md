# Changelog

All notable changes to the Lending Nelson project will be documented in this file.

## [1.2.0] - Phase 1 Borrower Portal Identity & Client Security Release

### Borrower Mobile Application (`apps/borrower_mobile`)

- **Dedicated Borrower Mobile App:** Initialized independent Flutter app with feature-first clean architecture (`apps/borrower_mobile/`).
- **Authentication & Security Boundary:** Implemented GoRouter route guards, Riverpod `AuthNotifier`, `SecureTokenStorage`, and Dio `AuthInterceptor` with token rotation and auto-refresh.
- **Phase 1 Screen Placeholders:** Created `/login`, `/verify`, `/home`, `/loans`, `/payments`, `/notifications`, and `/profile` screens.

### Backend (`/api/v1/client`)

- **Borrower Account Identity & Database Models:** Added `borrower_accounts`, `borrower_invitations`, `borrower_otps`, `borrower_refresh_tokens`, and `borrower_devices` tables via Alembic migration `018_add_borrower_portal_tables.py`.
- **JWT Audience Boundary:** Implemented `aud: borrower-app` token claim verification (`CurrentBorrowerAccount`, `ActiveBorrowerAccount`). Enforced strict cross-authentication rejection between officer and borrower endpoints.
- **Secure Account Linking:** Added officer client invitation endpoint (`POST /api/v1/borrowers/{borrowerId}/client-invitation`) for issuing 6-digit activation codes.
- **Cryptographic OTP & Privacy Safeguards:** Hashed 6-digit OTP codes, rate-limiting resend cooldowns, maximum verification attempt tracking, and non-enumerating public responses.

## [1.1.0] - Complete Offline-First Architecture Release

### Mobile Client (Flutter & SQLite)

- **Normalized Local Database (`v6`):** Created normalized SQLite tables for `borrowers`, `loans`, `loan_schedules`, `repayments`, `collections`, `guarantors`, `emergency_contacts`, `borrower_notes`, `documents`, `users`, `offline_sync_queue`, `sync_conflicts`, and `sync_metadata`. Added metadata fields: `local_id`, `server_id`, `created_at`, `updated_at`, `deleted_at`, `sync_status`, `sync_error`, `version`, `device_id`, `last_synced_at`.
- **Pure Dart Financial Calculation Parity:** Implemented `LoanCalculator` in Dart with exact integer minor currency units (cents) and `ROUND_HALF_UP` arithmetic, achieving 100% calculation parity with backend `loan_calculator.py`.
- **Offline-First Data Layer:** Refactored `BorrowerRepository`, `LocalLoanRepository`, `PaymentNotifier`, `BorrowersNotifier`, and `LoanCreateNotifier` to read from and write to local SQLite first. All core lending operations succeed immediately when offline.
- **Dependency-Aware Outbox Queue:** Enhanced `OfflineSyncService` outbox queue to sort pending mutations by entity dependency graph (Borrower -> Loan -> Repayment) and apply exponential backoff.
- **Sync & Conflict UI:** Created `SyncStatusBadge` and `SyncManagementScreen` (`/sync-management`) to provide real-time queue health stats, failed operation diagnostics, conflict inspection, and manual "Sync Now" triggers.

### Backend (FastAPI & PostgreSQL)

- **Enhanced Replay Safety & Idempotency:** `/api/v1/sync/drain` accepts client UUID transaction IDs and request UUIDs to reject duplicate submissions gracefully.
- **Incremental Sync Support:** Support for tracking synchronization cursors and last synced metadata.

### Testing & Verification

- 72 Flutter unit/widget tests passing (100%), including Dart `LoanCalculator` parity tests.
- 84 backend Python unit tests passing (100%).
- `flutter analyze` passing cleanly with zero warnings or errors.

## [1.0.0] - System Hardening & Production Reliability Release

### Backend (FastAPI & PostgreSQL)

- **Health Monitoring:** Implemented `/health/live` (lightweight process check) and `/health/ready` (PostgreSQL connectivity check via `SELECT 1`, returning HTTP 503 on database unavailability).
- **Environment & Config Safety:** Enforced `APP_ENV` validation (`development`, `test`, `staging`, `production`), strong JWT secret key requirements in production, and rejected wildcard CORS origins (`*`) when running in production.
- **Machine-Readable Sync Failures:** Extended `SyncFailure` schema with machine-readable error codes (`INVALID_PAYLOAD`, `RESOURCE_NOT_FOUND`, `IDEMPOTENCY_CONFLICT`, `INVALID_WORKFLOW_STATE`, `TEMPORARY_DATABASE_ERROR`) and `retryable` boolean flags.
- **Formalized Loan Workflows:** Enforced state transition policies, role permissions, and idempotent execution for loan lifecycle actions (`approve`, `disburse`, `activate`, `complete`, `default`, `cancel`, `close`).
- **Database Constraints & Alembic Check:** Model check constraints for principal, interest rate, term, payment amount, and idempotency request UUIDs verified with Alembic.

### Mobile Client (Flutter & SQLite)

- **Multi-State Reachability Service:** Centralized `ServerHealthService` and reactive `serverStatusNotifierProvider` tracking `offline`, `networkAvailable`, `serverUnavailable`, and `serverReady` states.
- **Reactive Sync Queue Notifier:** `offlineSyncQueueNotifierProvider` providing real-time UI updates on enqueue, retry, drain, and reset operations.
- **SQLite Queue Diagnostics Schema (v5):** Extended `offline_sync_queue` table with diagnostic columns: `status` (`pending`, `syncing`, `retryableFailed`, `permanentlyFailed`, `conflict`), `retry_count`, `last_attempt_at`, `last_error_code`, `last_error_message`, `next_retry_at`, and `server_resource_id`.
- **Automatic Crash Recovery & Backoff:** Automatically resets stale `syncing` queue records to `pending` on startup and applies bounded exponential backoff for retried operations.
- **Multi-State UI Banner:** Updated `MainShell` in `app_router.dart` with color-coded status messages reflecting exact connectivity and server readiness.
