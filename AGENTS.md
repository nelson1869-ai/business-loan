# AGENTS.md

## Project

Lending Nelson is an offline-first lending platform.

Repository consists of:

- Flutter Officer/Admin application (`lib/`)
- Flutter Borrower application (`apps/borrower_mobile/`)
- FastAPI backend (`backend/app/`)
- PostgreSQL
- SQLAlchemy 2 Async
- Alembic
- Riverpod
- Local SQLite offline storage
- Offline synchronization
- JWT authentication
- OTP borrower authentication

This project handles financial records and borrower PII.

Financial correctness, authorization, privacy and auditability are more important than speed.

---

## General Rules

Before writing code:

1. Inspect existing implementation.
2. Reuse existing architecture.
3. Never duplicate existing logic.
4. Extend instead of rewriting.
5. Keep changes minimal and reviewable.
6. Never commit unless instructed.
7. Never push unless instructed.

---

## Architecture

Backend

- FastAPI
- Feature-based modules
- SQLAlchemy 2 Async
- PostgreSQL
- Alembic
- Pydantic v2

Flutter

- Clean Architecture
- Riverpod
- Repository pattern
- Existing API layer
- Existing routing
- Existing theme

Do not introduce another architecture.

---

## Financial Rules

Money is critical.

Never:

- use floating point for money
- silently round values
- rewrite financial calculations
- delete ledger history

Backend is always the source of truth for:

- balances
- schedules
- receipts
- statements
- reports
- payment allocation

Flutter displays backend results.

---

## Offline Rules

Officer application is offline-first.

Never break:

- SQLite
- Sync Queue
- Retry
- Conflict handling
- UUID idempotency
- Server-off workflow

Every new synchronized entity must define:

- local storage
- sync payload
- retry
- conflict
- dependency
- tests

---

## Borrower App Rules

Borrower application is separate.

Never expose:

- admin pages
- officer features
- management APIs

Borrowers only access:

- profile
- dashboard
- loans
- schedules
- receipts
- payment history

Borrowers never modify financial records.

---

## Borrower Registration

Workflow:

Borrower
→ Register
→ Pending

Admin
→ Review
→ Link to existing borrower
→ Approve

Borrower
→ OTP Verification
→ Active

Never:

- auto approve
- auto link by name
- trust borrowerId from client

Only backend assigns borrower relationships.

---

## Authentication

Officer authentication and borrower authentication are separate.

Preserve:

- JWT
- Refresh Tokens
- OTP
- Device registration

Never log:

- tokens
- OTP
- passwords
- secrets

---

## Authorization

Authorization belongs in backend.

Never trust:

- borrowerId
- userId
- role
- account status

coming from client requests.

---

## Database

Every schema change requires:

- Alembic migration
- tests
- documentation updates

Never modify old migrations.

---

## API Rules

Use:

- Request schemas
- Response schemas
- Validation
- Proper HTTP status codes

Never expose:

- SQL errors
- stack traces
- secrets

---

## Security

Always protect:

- borrower PII
- phone numbers
- documents
- balances
- payments

Mask sensitive information in logs.

Never commit:

- .env
- keys
- passwords
- JWT secrets
- borrower data

---

## Flutter Rules

Reuse:

- providers
- repositories
- widgets
- theme
- navigation

Do not create duplicate state management.

Avoid business logic inside widgets.

---

## Testing

Every feature requires tests.

Run relevant project checks before completion.

Do not report tests as passing unless actually executed.

---

## Git Rules

Before work:

git status

Review changes before commit.

Keep commits focused.

Never commit generated files.

Never push unless instructed.

---

## Documentation

Update documentation whenever:

- API changes
- database changes
- authentication changes
- architecture changes
- deployment changes

---

## Task Completion Report

After completing work provide:

- Summary
- Files changed
- Database changes
- API changes
- Flutter changes
- Tests added
- Verification results
- Known limitations
- git status
- Suggested commit message

---

## Absolute Rules

Never:

- expose another borrower's data
- bypass authorization
- bypass validation
- commit secrets
- connect Flutter directly to PostgreSQL
- weaken security to satisfy tests
- rewrite working architecture
- auto approve borrower registration
- auto link borrower accounts
- remove audit logging
- break offline synchronization
- claim tests passed when they were not run
- commit or push unless explicitly instructed
