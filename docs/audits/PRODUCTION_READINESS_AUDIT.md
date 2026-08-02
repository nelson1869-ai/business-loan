# Production Readiness Audit

**Audit date:** 2026-08-02  
**Scope:** Flutter officer app, Flutter borrower app, FastAPI backend, PostgreSQL/Alembic, offline synchronization, n8n integration, CI, tests, and operations documentation.  
**Method:** Repository search and direct inspection. A capability is called missing only where no equivalent model, service, migration, API, test, workflow, or runbook was found.

## Executive summary

> Implementation update (2026-08-02): the gap analysis below records the
> repository at the start of the hardening work. The worktree now contains
> policy versions, accounting journals, collection sessions, granular
> permissions, maker-checker requests, write-off/recovery records, reports,
> migrations through `031`, and related tests. This document remains historical
> evidence; current release readiness must be determined from fresh command
> results, not the original counts below.

The repository already has a strong transactional lending core: exact `Decimal` calculations, PostgreSQL `NUMERIC` money columns, row-locked and idempotent loan/payment commands, append-only payment reversals, offline replay receipts, audit events, borrower/officer token separation, refresh-token rotation, and a durable n8n outbox. These controls should be preserved.

The largest confirmed production gaps are policy provenance, general accounting, cash custody/reconciliation, and granular authorization. Current loans persist their calculation inputs but have no immutable loan-product policy reference or snapshot. The existing payment ledger is not double-entry accounting. Collection tasks manage field work but do not establish accountable opening cash, expected/actual cash, handover, deposit, variance review, or closeout. Authorization is mostly direct role comparison (`admin`, `officer`, and borrower audience checks), with no permission catalog or generic maker-checker record.

Operationally, CI is useful but lacks enforced coverage thresholds, focused type checking, release-signing/configuration validation, and explicit backup/restore verification. No repository runbook proves an automated encrypted backup process exists.

## Current structure

| Component | Location | Confirmed responsibility |
|---|---|---|
| Officer Flutter application | repository root `lib/`, `test/` | Offline-first officer workflows, encrypted local data, sync queue, loans, payments, collection tasks, reports, settings |
| Borrower Flutter application | `apps/borrower_mobile/` | OTP authentication, dashboard, loan/payment/profile projections and isolated local caches |
| FastAPI backend | `backend/app/` | Authoritative lending rules, authentication, persistence, replay, projections, and integrations |
| PostgreSQL schema | `backend/alembic/versions/` | 20 sequential migrations at audit start; policy implementation advanced the single head to `022` |
| n8n | `n8n/workflows/` | Event routing, receipts, sync alerts, Telegram management, and workflow error handling |
| CI | `.github/workflows/` | Flutter/backend quality, PostgreSQL migration tests, dependency audit, secret scan, dependency review |

## Existing strengths

### Financial integrity

- `backend/app/features/loans/calculator.py` rejects binary floats, uses `Decimal`, centralizes cent rounding, constructs schedules, prorates interest, and allocates payments interest-first.
- `backend/app/features/loans/models.py` uses `NUMERIC(18,2)` for money and `NUMERIC(10,8)` for rates, with non-negative checks and restricted financial foreign-key deletion.
- `backend/app/features/payments/models.py` stores immutable `Payment`/`Reversal` entries and one exact before/allocation/after snapshot per entry. Unique request IDs and unique reversal links protect replay and one-time reversal.
- `backend/app/features/payments/service.py` locks the loan for payment/reversal, recalculates server-side, restores economic state through a compensating reversal entry, and never deletes the original payment.
- PostgreSQL concurrency coverage exists in `test_loan_idempotency_postgres.py` and `test_payment_idempotency_postgres.py`.
- Projection tests distinguish unpaid due amounts from total portfolio exposure (`test_report_formulas.py`).

### Reliability and offline operation

- `backend/app/features/sync/router.py` replays an allowlisted set of offline mutations and commits the mutation and `SyncReceipt` together.
- `backend/app/features/sync/models.py` scopes durable transaction UUID receipts to the actor; replay ownership conflicts fail closed.
- Officer-side sync code and tests cover dependency ordering, leases, coalescing, retry behavior, response validation, conflict recovery, and two-device-style idempotent replay.
- `backend/app/features/automation/models.py` provides a unique idempotency key, correlation ID, retry state, and dead-letter status for n8n events.
- `backend/app/features/automation/outbox.py` uses `FOR UPDATE SKIP LOCKED`, bounded attempts, backoff, jitter, HMAC signing, and manual replay.

### Authentication and security

- `backend/app/core/config.py` requires `APP_ENV`, rejects weak JWT secrets, rejects wildcard production CORS, and refuses the fixed borrower OTP outside exact `development`.
- Officer and borrower tokens have separate authorization boundaries; borrower access tokens require the `borrower-app` audience and borrower claims.
- Borrower refresh tokens are stored hashed, rotated, linked to devices, expire, and trigger all-session revocation on reuse.
- OTP records retain hashes, expiry, resend cooldown, use-once state, and attempt limits.
- Document and PII tests cover signature validation, filename sanitization, authorization, masking, and absence of hardcoded Python database passwords.

### Auditability and CI

- `AuditLog` records actor, action, entity, old/new state fields, and timestamp; loan creation/transitions, payment mutation, user administration, and business setting changes emit audit records.
- `.github/workflows/ci.yml` runs root and borrower Flutter formatting/analyze/tests, backend Ruff, PostgreSQL migrations, `alembic check`, pytest coverage reporting, migration downgrade/upgrade, n8n validation, `pip-audit`, Gitleaks, and dependency review.
- At audit time, Alembic reports exactly `020 (head)` and pytest collects 215 backend tests.

## Confirmed gaps

### 1. Versioned financial policies

**Evidence:** `BusinessSetting` contains presentation fields only (`business_name`, `currency_code`, `receipt_footer`). `Loan` persists raw terms and `calculation_method` but no policy version ID or immutable policy snapshot. Repository search found policy prose in `docs/domain/LOAN_AND_PAYMENT_RULES.md`, but no policy model, approval workflow, or activation endpoint.

**Gap:** A future configuration system cannot prove which approved policy governed a historical loan. The code currently avoids this risk by having few global financial settings, but it cannot safely add configurable fees, rounding, allocation, settlement, restructuring, or write-off behavior without policy provenance.

### 2. Double-entry accounting

**Evidence:** `Payment` and `PaymentAllocation` are called a ledger and are appropriately append-only, but no `Account`, `JournalEntry`, `JournalLine`, `AccountingPeriod`, balanced-entry constraint/service, trial balance, or posting rule exists.

**Gap:** Loan disbursement, principal/interest receipt, unapplied credit, reversal, write-off, recovery, cash handover, and bank deposit do not produce balanced accounting journals. Financial payment history therefore cannot by itself support a general ledger or audited trial balance.

### 3. Cash collection and reconciliation

**Evidence:** `backend/app/features/collection/` and migrations `007`-`009` implement assigned collection tasks, state transitions, and promises to pay. Payments have request IDs and receipt projections. No collection-session, opening/expected/actual cash, variance, handover, deposit, reviewer, or reconciliation model was found.

**Gap:** The system cannot establish custody or reconcile field cash to recorded payments and deposits. Receipt uniqueness is not a substitute for session-level cash control.

### 4. Granular authorization and maker-checker

**Evidence:** `User.role` and direct checks such as `current_user.role != "admin"` protect administrative routes; collection task rules restrict assignment; borrower tokens are separately authorized. No permission table/catalog, role-permission mapping, approval request, maker/checker separation, or approval threshold model was found.

**Gap:** Roles cannot express least privilege for collector, cashier, auditor, manager, and support duties. Loan approval/disbursement, reversals, policy activation, write-off, restructuring, variance approval, and manual journals lack a reusable two-person authorization record.

### 5. Backup and disaster recovery

**Evidence:** Documentation search found a settings UI reference to backup but no `BACKUP_AND_RESTORE.md`, disaster-recovery runbook, tested PostgreSQL backup script, restore verification, RPO/RTO declaration, or lost-device/compromised-account response runbook.

**Gap:** No automated backup capability is proven. Operators do not have repository-controlled restore, corruption, credential rotation, n8n recovery, Firebase recovery, or offline-data limitation procedures.

### 6. Testing and CI enforcement

**Evidence:** Property-based tests using Hypothesis were not found. `pyrightconfig.json` names the backend environment but has no focused strict include/rules, and CI does not invoke Pyright/mypy. Coverage is reported but no 85/90/95 percent thresholds are enforced. CI builds a borrower debug APK, not a production-signed release artifact.

**Gap:** Important invariants have example and concurrency coverage, but broad generated boundary coverage and enforceable coverage/type/release gates are missing.

### 7. Reporting

**Evidence:** Dashboard/projection/report services and officer report UI exist. Repository search did not find reproducible PAR 1/7/30/60/90, vintage, repeat-borrower, restructuring, write-off/recovery, collector variance, or daily trial-balance reports backed by policy/accounting/reconciliation data.

**Gap:** Existing operational projections are not a complete historical management-reporting suite. Several requested reports depend on accounting and policy data that do not yet exist.

### 8. Production build separation

**Evidence:** Both Flutter apps accept compile-time API configuration, and backend environment validation is strong. Explicit development/staging/production Flutter flavors and production gates for localhost URLs, debug logging, development OTP display, Firebase project separation, and signing configuration were not found in CI.

**Gap:** Build-time environment separation relies on operator discipline rather than a complete fail-closed release pipeline.

## Risks

### Security risks

1. Coarse roles can over-authorize staff once cashier, collector, auditor, or support accounts are introduced.
2. Sensitive actions lack generic maker-checker separation and structured approval/rejection reasons.
3. Release configuration is not yet proven to fail closed for all development flags and localhost endpoints.
4. Audit records are application-protected but no database rule currently prevents update/delete by a privileged application role.

### Financial-integrity risks

1. Historical loans have terms but no approved policy provenance.
2. Payment history is not a balanced general ledger; cash, receivable, income, credit, and bank positions cannot be reconciled through journals.
3. Reversals restore lending balances correctly, but do not yet create compensating accounting entries.
4. Write-off, recovery, restructuring, configured fees, and early settlement lack approved versioned rules and should remain disabled until policy approval.

### Operational risks

1. No accountable collection-session closeout exists for field cash.
2. No documented or tested recovery process establishes responsibilities, RPO, RTO, or restore verification.
3. Manual role checks will become difficult to audit as staff responsibilities expand.
4. n8n has a durable backend outbox, but end-to-end platform recovery procedures are absent.

### Data-loss risks

1. No verified encrypted off-device PostgreSQL backup automation exists in the repository.
2. Offline device data may contain mutations not yet accepted by the server; recovery limitations are undocumented.
3. Keystore, Firebase, n8n, and database credential recovery responsibilities are not documented.

## Recommended implementation order

1. **Authorization primitives and policy versions:** establish permission checks and maker-checker records needed to approve policies safely; attach an immutable policy version to new loan approvals/disbursements.
2. **Double-entry foundation:** add chart of accounts, periods, immutable balanced journals, idempotent posting, and postings for existing loan/payment/reversal flows.
3. **Cash collection sessions:** bind cash payments to accountable sessions and post handover/deposit journals; add variance approval.
4. **Sensitive workflow expansion:** restructuring, write-off, recovery, manual adjustments, and thresholds only after policy/accounting/approval foundations exist.
5. **Historical reports:** implement PAR/aging first from existing schedules, then accounting/reconciliation reports after their source records exist.
6. **Reliability gates:** property/concurrency tests, focused strict typing, coverage thresholds, migration gates, and production release validation.
7. **Operations:** tested backup/restore scripts and incident runbooks before declaring production readiness.

## Intentionally unresolved policy and legal decisions

The implementation must provide configuration and approval structures but must not choose the business's final values for late fees, grace periods, compounding, early settlement, restructuring, write-off authority, material variance, approval thresholds, retention periods, RPO, or RTO. Those values require documented business ownership and, where applicable, legal/regulatory review.

## Files inspected

- Backend configuration/core: `backend/app/core/config.py`, `database.py`, `dependencies.py`, security middleware and rate-limiter modules.
- Loans/payments: feature models, schemas, routers, calculator, services, and migrations `002`-`005`.
- Users/audit/settings: user models/router, `AuditLog`, business settings model/router, bootstrap code.
- Collections: collection models/router/schemas and migrations `007`-`009`.
- Sync: sync models/router/schemas, migrations `014` and `016`, officer offline-sync implementation and tests.
- Borrower portal: models, dependencies, permissions, OTP provider, auth service, dashboard/loan/payment/profile services and tests, migrations `018`-`020`.
- Automation: outbox model/service/router, HMAC code, migration `017`, n8n workflows and validator.
- Projections/reports: projection router/schemas/service, report formula tests, officer dashboard/report repositories and UI.
- Delivery/operations: `.github/workflows/ci.yml`, dependency-review workflow, `pyproject.toml`, `pyrightconfig.json`, root/backend/borrower READMEs, `docs/`, scripts, Android Gradle configuration, and environment examples.
- Migration chain: all files `001` through `020` were audited; policy migrations `021` and `022` were then added. `python -m alembic heads` returns one head, `022`, and `alembic check` reports no drift.
- Test inventory: backend `pytest --collect-only` returned 215 tests; borrower Flutter full suite returned 39 passing tests during the current work session.

## Audit limitations

- This is a repository audit, not a legal, regulatory, infrastructure, penetration-testing, or independent financial audit.
- Presence of scripts or CI configuration does not prove deployed schedules, off-device retention, monitoring, or restore success.
- The worktree contained pre-existing uncommitted changes during inspection; implementation must preserve and isolate them.
