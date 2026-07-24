# Lending Nelson Current TODO

Completed history belongs in [Development Log](docs/history/DEVELOPMENT_LOG.md). The full remaining plan is in [Delivery Milestones](docs/roadmap/MILESTONES.md).

## Completed: System Hardening & Reliability

- [x] Implemented `/health/live` (process liveness) and `/health/ready` (PostgreSQL connectivity check returning HTTP 503 on failure).
- [x] Separated physical network interface connectivity from backend server reachability (`offline`, `networkAvailable`, `serverUnavailable`, `serverReady`).
- [x] Made offline queue count reactive in Riverpod (`offlineSyncPendingCountProvider`, `offlineSyncQueueNotifierProvider`).
- [x] Upgraded SQLite schema to v5 with diagnostic columns (`status`, `retry_count`, `last_attempt_at`, `last_error_code`, `last_error_message`, `next_retry_at`).
- [x] Implemented startup crash recovery (resetting `syncing` to `pending`) and bounded exponential backoff for queue retries.
- [x] Added machine-readable backend sync failure codes (`INVALID_PAYLOAD`, `RESOURCE_NOT_FOUND`, `IDEMPOTENCY_CONFLICT`, `INVALID_WORKFLOW_STATE`, `TEMPORARY_DATABASE_ERROR`).
- [x] Added `OfflineQueueInspectionPage` under Dev Tools / Settings for queue diagnostics and safe purging.
- [x] Restricted development-only admin endpoints (`/api/v1/admin/reset`, `/api/v1/admin/seed`) when `APP_ENV=production`.
- [x] Enforced backend configuration safety (JWT secret strength, CORS origin controls in production).
- [x] Formalized loan workflow state transitions and audit log safety.
- [x] Verified 100% test pass rate across Python unittests (81), Flutter tests (64), and Postman API regression (68 endpoints, 124 assertions).

## Next priority: Additional UI Projections & Staging

- [ ] Add PDF export capability for loan statements and payment receipts.
- [ ] Add push notification triggers for overdue collection reminders.
