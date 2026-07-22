# Development Log

This file preserves dated engineering history. Test counts below describe the repository at that date and are not current verification results. Use [backend/README.md](../../backend/README.md) and [postman/README.md](../../postman/README.md) for current commands and results.

## 2026-07-19 — Loan persistence foundation

- Added PostgreSQL loan and installment models and migrations.
- Added loan schemas and authenticated create/list/detail routes.
- Persisted reducing-balance schedules and audit events transactionally.

## 2026-07-19 — Flutter loan integration

- Added Flutter loan and installment models and authenticated repositories.
- Added borrower loan lists, loan creation, and schedule detail screens.
- Kept authoritative schedule calculations in the backend.

## 2026-07-19 — Idempotent loan creation

- Added unique loan request IDs and migration `003`.
- Added safe replay, conflicting-term rejection, and concurrent retry handling.
- Flutter began retaining UUIDs for unchanged retries.

## 2026-07-19 — Flexible payments

- Added payment and allocation ledger models in migration `004`.
- Added preview and confirmation for full, partial, early, late, interest-only, and excess payments.
- Added row locking and request-ID idempotency.
- Historical verification at this point reported 52 backend tests and 31 Flutter tests.

## 2026-07-19 — Payment reversals

- Added reasoned full reversal of the latest eligible payment.
- Preserved original rows and reconstructed balances and schedule states.
- Added Flutter reversal controls and ledger labels.
- Historical verification at this point reported 58 backend tests and 32 Flutter tests.

## 2026-07-20 — UI and backend-aligned enhancements

- Standardized loan date formatting and added principal presets.
- Added manual offline synchronization and a pending-queue badge.
- Added local audit-log viewing and borrower search.
- Added exposure and overdue collection alerts.
- Historical verification at this point reported 59 backend tests and 53 Flutter tests.

## 2026-07-22 — Development tooling and cleanup

- Added the development loan-status endpoint and richer seeded scenarios.
- Added Active, Overdue, Paid, and Today's Collections seed data.
- Removed obsolete widgets and stabilized navigation tests.
- Historical verification at this point reported 59 backend tests and 56 Flutter tests.

## 2026-07-22 — Backend financial projections and workflows

- Added receipt and loan-statement projections from ledger data.
- Added dashboard and financial-report projections.
- Added stable pagination for loans and payments.
- Added approve, disburse, activate, default, cancel, and close workflow behavior.
- Expanded offline sync to loans, payments, and reversals.
- Verified 63 backend tests with 3 skipped and no failures.

## 2026-07-22 — Complete Postman regression suite

- Organized 68 requests into deterministic setup, domain, projection, sync, negative, and cleanup folders.
- Added 124 meaningful assertions, including Decimal-safe reconciliation checks.
- Verified all 68 requests and 124 assertions with zero failures.

## Adding future entries

Use this format:

```text
## YYYY-MM-DD — Short outcome

- Capability added or changed.
- Important architecture or business-rule decision.
- Verification performed at that time.
```

Do not turn this historical log into current setup documentation or a personal checklist.
