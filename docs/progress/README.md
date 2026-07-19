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
- [ ] Write and pass one Flutter unit test.
- [ ] Write and pass one Flutter widget test.
- [ ] Run `flutter analyze` with no issues.
- [ ] Run the complete Flutter test suite.

## 3. Backend progress

Study details: [FastAPI Backend Study Guide](../backend/README.md)

- [ ] Explain how `main.py` creates the FastAPI application.
- [ ] Identify every registered API router.
- [ ] Explain request validation with Pydantic schemas.
- [ ] Explain async database sessions.
- [ ] Create a development officer with the bootstrap command.
- [ ] Reset a development officer password.
- [ ] Log in through Swagger and inspect the token response.
- [ ] Explain password hashing and why hashes cannot be reversed.
- [ ] Explain access and refresh JWTs.
- [ ] Trace borrower creation from router to PostgreSQL.
- [ ] Trace borrower editing from router to PostgreSQL.
- [ ] Explain soft deletion.
- [ ] Inspect a redacted audit record.
- [ ] Apply all Alembic migrations.
- [ ] Explain how to create a new Alembic migration.
- [ ] Run `python -m alembic check` successfully.

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
- [ ] Verify reducing-balance interest after a partial monthly payment.
- [ ] Create two loans with different lender-selected rates and verify both.
- [ ] Generate and explain a 5-month schedule with 10 installments.
- [ ] Verify the final installment clears the rounding balance exactly.

## 5. Code quality and security

- [ ] Confirm secrets are excluded by `.gitignore`.
- [ ] Confirm no real password or token is committed for production use.
- [ ] Format modified Dart files.
- [ ] Run Flutter analysis and tests before committing.
- [ ] Review `git diff` before staging.
- [ ] Use a focused conventional commit message.
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
