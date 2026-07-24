# Changelog

All notable changes to the Lending Nelson project will be documented in this file.

## [Unreleased] - System Hardening & Production Reliability Release

### Backend (FastAPI & PostgreSQL)
- **Health Monitoring:** Implemented `/health/live` (lightweight process check) and `/health/ready` (PostgreSQL connectivity check via `SELECT 1`, returning HTTP 503 on database unavailability).
- **Environment & Config Safety:** Enforced `APP_ENV` validation (`development`, `test`, `staging`, `production`), strong JWT secret key requirements in production, and rejected wildcard CORS origins (`*`) when running in production.
- **Admin Endpoint Protection:** Restricted development-only admin routes (`/api/v1/admin/reset`, `/api/v1/admin/seed`, `/api/v1/admin/loans/{id}/status`) from being registered outside development/test environments.
- **Machine-Readable Sync Failures:** Extended `SyncFailure` schema with machine-readable error codes (`INVALID_PAYLOAD`, `RESOURCE_NOT_FOUND`, `IDEMPOTENCY_CONFLICT`, `INVALID_WORKFLOW_STATE`, `TEMPORARY_DATABASE_ERROR`) and `retryable` boolean flags.
- **Formalized Loan Workflows:** Enforced state transition policies, role permissions, and idempotent execution for loan lifecycle actions (`approve`, `disburse`, `activate`, `complete`, `default`, `cancel`, `close`).
- **Database Constraints & Alembic Check:** Model check constraints for principal, interest rate, term, payment amount, and idempotency request UUIDs verified with Alembic.

### Mobile Client (Flutter & SQLite)
- **Multi-State Reachability Service:** Centralized `ServerHealthService` and reactive `serverStatusNotifierProvider` tracking `offline`, `networkAvailable`, `serverUnavailable`, and `serverReady` states.
- **Reactive Sync Queue Notifier:** `offlineSyncQueueNotifierProvider` providing real-time UI updates on enqueue, retry, drain, and reset operations.
- **SQLite Queue Diagnostics Schema (v5):** Extended `offline_sync_queue` table with diagnostic columns: `status` (`pending`, `syncing`, `retryableFailed`, `permanentlyFailed`, `conflict`), `retry_count`, `last_attempt_at`, `last_error_code`, `last_error_message`, `next_retry_at`, and `server_resource_id`.
- **Automatic Crash Recovery & Backoff:** Automatically resets stale `syncing` queue records to `pending` on startup and applies bounded exponential backoff for retried operations.
- **Queue Inspection Screen:** Created `OfflineQueueInspectionPage` accessible via Dev Tools / Settings to inspect diagnostic items, retry failures, copy safe summaries, or remove queue items.
- **Multi-State UI Banner:** Updated `MainShell` in `app_router.dart` with color-coded status messages reflecting exact connectivity and server readiness.

### Testing & Quality Assurance
- 81 backend unit tests passing (100%).
- 64 Flutter unit/widget tests passing (100%).
- 68 Postman/Newman API regression tests with 124 assertions passing (100%).
- `flutter analyze` passing with zero warnings or errors.
