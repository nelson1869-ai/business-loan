# Lending Nelson TODO

Only the current step is shown here. Complete and verify it before adding the
next step.

Long-term work remains in the [Product Roadmap](docs/roadmap/README.md).

## Step 6: Make loan creation idempotent

Goal: guarantee that repeated taps, network retries, or a response failure can
never create more than one loan for the same submission.

1. [x] Add a unique loan request ID column and PostgreSQL Alembic migration.
2. [x] Make FastAPI return the existing loan when a request ID is retried.
3. [x] Make Flutter generate and reuse one request ID for each submission.
4. [x] Test repeated taps, timeouts, and retries to prove only one loan exists.
5. [x] Run all checks, update student documentation, and commit Step 6.

Idempotency rules:

- Flutter generates a UUID before the first loan-creation request;
- retries of that submission reuse the same UUID;
- PostgreSQL enforces uniqueness instead of relying only on UI state;
- FastAPI returns the original loan and schedule for a repeated UUID;
- a UUID cannot silently represent different loan terms; and
- historical duplicate development rows are not deleted automatically.

Step 6 is complete only when identical retries return one persisted loan and a
conflicting reuse of a request ID is rejected safely. After that, replace this
step with Step 7 for recording full, partial, interest-only, early, and late
payments.
