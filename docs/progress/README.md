# Student Progress Tracker

Use this checklist to track what you have studied and demonstrated. Check an
item only after you can explain it and show it working.

## How to use this tracker

- `[ ]` Not started
- `[-]` In progress
- `[x]` Completed and verified

Update the checkbox and add a short entry to the learning log at the bottom.
Commit progress updates separately from application code when possible.

## 1. Project orientation

- [ ] Read the [Student Guide](../STUDENT_GUIDE.md).
- [ ] Review the [Visual Flow](../VISUAL_FLOW.md).
- [ ] Run the Flutter application.
- [ ] Run the FastAPI backend.
- [ ] Open the FastAPI Swagger page.
- [ ] Explain why Flutter does not connect directly to PostgreSQL.

## 2. Frontend progress

Study details: [Flutter Frontend Study Guide](../frontend/README.md)

- [ ] Explain `main.dart` and `ProviderScope`.
- [ ] Explain `MaterialApp.router` and GoRouter navigation.
- [ ] Identify presentation, domain, and data layers.
- [ ] Trace login from the form to `AuthRepository`.
- [ ] Explain Riverpod provider state and UI rebuilding.
- [ ] Register a borrower and validate every field.
- [ ] Edit an existing borrower.
- [ ] Delete an existing borrower.
- [ ] Explain local SQLite storage.
- [ ] Explain local PII encryption.
- [ ] Explain Dio access-token and refresh-token handling.
- [ ] Explain how an offline mutation enters the sync queue.
- [x] Write and pass one Flutter unit test.
- [x] Write and pass one Flutter widget test.
- [x] Run `flutter analyze` with no issues.
- [x] Run the complete Flutter test suite.

## 3. Backend progress

Study details: [FastAPI Backend Study Guide](../backend/README.md)

- [ ] Explain how `main.py` creates the FastAPI application.
- [x] Identify every registered API router.
- [x] Explain request validation with Pydantic schemas.
- [x] Explain async database sessions.
- [ ] Create a development officer with the bootstrap command.
- [ ] Reset a development officer password.
- [ ] Log in through Swagger and inspect the token response.
- [ ] Explain password hashing and why hashes cannot be reversed.
- [ ] Explain access and refresh JWTs.
- [ ] Trace borrower creation from router to PostgreSQL.
- [ ] Trace borrower editing from router to PostgreSQL.
- [ ] Explain soft deletion.
- [ ] Inspect a redacted audit record.
- [x] Apply all Alembic migrations.
- [ ] Explain how to create a new Alembic migration.
- [x] Run `python -m alembic check` successfully.

## 4. Frontend and backend integration

- [ ] Explain `localhost` versus Android emulator `10.0.2.2`.
- [ ] Log in from Android using the FastAPI backend.
- [ ] Register a borrower and confirm it exists in SQLite and PostgreSQL.
- [ ] Edit a borrower and confirm both databases are updated.
- [ ] Delete a borrower and confirm local and remote behavior.
- [ ] Trigger and explain an HTTP 401 response.
- [ ] Trigger and explain an HTTP 422 response.
- [ ] Demonstrate an offline borrower operation.
- [ ] Reconnect and confirm the queued operation synchronizes.
- [ ] Explain how legacy local-only borrowers are migrated remotely.
- [ ] Record a payment five days after its due date and verify overdue interest.
- [ ] Compare full, interest-only, and partial payments made five days early.
- [x] Trace payment preview and confirmation from Flutter to PostgreSQL.
- [x] Verify an extra payment reduces principal immediately.
- [x] Verify repeated payment requests create only one ledger entry.
- [x] Reverse a payment and verify its original ledger row remains unchanged.
- [x] Verify concurrent reversal retries restore the balance only once.
- [x] Verify reducing-balance interest after a partial monthly payment.
- [ ] Create two loans with different lender-selected rates and verify both.
- [x] Generate and explain a 5-month schedule with 10 installments.
- [x] Verify the final installment clears the rounding balance exactly.

## 5. Code quality and security

- [ ] Confirm secrets are excluded by `.gitignore`.
- [ ] Confirm no real password or token is committed for production use.
- [ ] Format modified Dart files.
- [x] Run Flutter analysis and tests before committing.
- [x] Review `git diff` before staging.
- [x] Use a focused conventional commit message.
- [ ] Explain why borrower PII is redacted from audit logs.
- [ ] Explain why PostgreSQL must not be exposed directly to Flutter.

## 6. Suggested milestones

| Milestone | Completion requirement | Status |
| --- | --- | --- |
| M1: Setup | Flutter, FastAPI, and PostgreSQL run locally | Not started |
| M2: Frontend | Navigate, validate forms, and explain Riverpod | Not started |
| M3: Backend | Authenticate and explain one complete API request | Not started |
| M4: CRUD | Create, edit, and delete borrowers end to end | Not started |
| M5: Offline | Queue and synchronize an offline operation | Not started |
| M6: Quality | Analysis, tests, security review, and clean commit pass | Not started |

Change milestone status to `In progress`, `Blocked`, or `Completed`. If a
milestone is blocked, record the reason and next action in the learning log.

## 7. Learning log

### 2026-07-19 — Loan persistence foundation

- Added exact PostgreSQL loan and installment models and migration.
- Added validated loan API schemas and authenticated create/list/detail routes.
- Loan creation now calculates and persists the full reducing-balance schedule
  and an immutable audit event in one transaction.
- Verification: all backend unit and API-contract tests, Flutter analysis, and
  the complete Flutter test suite passed.

### 2026-07-19 — Flutter loan integration

- Added exact loan/installment models and authenticated repository requests.
- Added borrower loan lists, a validated create-loan form, and schedule details.
- Confirmed Flutter displays backend calculations instead of recalculating them.
- Verification: Flutter analysis, the complete Flutter suite, backend tests, and
  Alembic schema checks passed.

### 2026-07-19 — Idempotent loan creation

- Added unique PostgreSQL loan request IDs and migration `003`.
- Added safe replay, conflicting-term rejection, and concurrent retry handling.
- Flutter now reuses a UUID for unchanged retries and replaces it after edits.
- Verification: repeated-tap and timeout widget tests, backend unit tests, and a
  live two-session PostgreSQL row-count test passed.

### 2026-07-19 — Immutable flexible payments

- Added payment and one-to-one allocation ledger tables in migration `004`.
- FastAPI previews and confirms full, partial, early, late, interest-only, and
  excess payments using exact decimal calculations.
- Flutter shows the backend preview, confirms it, and displays payment history.
- Row locking and unique request UUIDs prevent duplicate balance changes.
- Verification: 52 backend tests, both live PostgreSQL concurrency tests,
  Flutter analysis, 31 Flutter tests, and Alembic schema checks passed.

### 2026-07-19 — Safe payment reversals

- Added reasoned, full-payment reversals for the latest eligible payment.
- Reversals preserve original rows and reconstruct principal, installment paid
  amounts, schedule statuses, carried interest, and loan status atomically.
- Flutter labels original and reversal entries and retains a UUID across an
  unchanged failed retry.
- Verification: 58 backend tests, three live PostgreSQL concurrency tests,
  Flutter analysis, 32 Flutter tests, and Alembic schema checks passed.

### 2026-07-20 — Senior Developer UI Audit & Backend-Aligned Enhancements

- Standardized date formatting to short dates (`M/D/YYYY`) in LoanDateField and LoanCreateScreen.
- Added quick principal preset action chips (`[$500]`, `[$1,000]`, `[$2,000]`, `[$5,000]`) in LoanCreateScreen.
- Added manual `Sync Offline Data` action in SettingsPage invoking `OfflineSyncService.drainQueue()`.
- Added real-time pending offline sync item counter badge (`☁️ count`) in Dashboard AppBar.
- Added local `AuditLog` security table viewer modal in SettingsPage.
- Integrated query parameter & client-side live search filtering (`/borrowers?query=`) into BorrowerListPage.
- Verification: 59 backend tests, 53 Flutter tests, and zero flutter analyze warnings.

### 2026-07-20 — Production Field & Risk Management Features

- Added real-time offline connectivity status banner (`⚡ Working Offline — N items queued`) in top navigation shell (`MainShell`).
- Added borrower portfolio exposure risk card (`Borrower Exposure Risk: N Active Loan(s) · $Total Balance`) on `LoanCreateScreen`.
- Added overdue arrears collection alert banner (`Payment Overdue — Immediate Collection Recommended`) on `LoanDetailScreen`.
- Verification: 59 backend tests, 53 Flutter tests, and zero flutter analyze warnings.

### 2026-07-22 — Admin Status Tooling, Seeding Enhancements & Codebase Audit Cleanup

- Added `POST /api/v1/admin/loans/{loan_id}/status` endpoint allowing dev status overrides and setting installment due dates to today.
- Enhanced `tool/seed_data.dart` to populate Active, Overdue, Paid, and Today's Collections scenarios.
- Audited codebase and removed unused legacy widgets (`borrower_info_section.dart`, `borrower_status_section.dart`, `financial_summary_section.dart`) and empty test directories.
- Fixed widget test hanging issue in `navigation_test.dart` by overriding network connectivity and remote repository providers.
- Verification: 59 backend tests, 56 Flutter unit & widget tests, 0 `flutter analyze` warnings.

Copy this entry whenever you complete a study session:

```text
Date:
Topic:
What I learned:
File(s) studied:
Command(s) run:
Test or evidence:
Problem encountered:
How I solved it:
Next step:
```

## 8. Final student demonstration

The project is ready for demonstration when you can:

1. Start PostgreSQL, FastAPI, and Flutter without assistance.
2. Explain the complete login and borrower data flows.
3. Demonstrate borrower CRUD from the Android app.
4. Explain the roles of SQLite and PostgreSQL.
5. Demonstrate testing, debugging, and safe Git practices.
