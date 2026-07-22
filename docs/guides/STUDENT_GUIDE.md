# Lending Nelson Student Guide

This guide provides an end-to-end learning path through the current Flutter and FastAPI application.

Start with the [System Overview](../architecture/SYSTEM_OVERVIEW.md), then keep the [Data Flows](../architecture/DATA_FLOWS.md) open while reading code.

## What you will learn

- Feature-oriented Flutter development with Riverpod and GoRouter
- Authenticated Dio requests and token refresh
- Encrypted SQLite caching and offline mutation queues
- FastAPI routing and Pydantic v2 validation
- Async SQLAlchemy and PostgreSQL migrations
- Exact financial calculations with `Decimal`
- Immutable payment and reversal ledgers
- Backend-generated receipts, statements, dashboards, and reports
- Idempotent loan, payment, and reversal requests
- Automated backend and Postman verification

## Recommended learning path

1. Follow [QUICK_START.md](../QUICK_START.md) and run PostgreSQL, FastAPI, and Flutter.
2. Open Swagger at `http://127.0.0.1:8000/docs`.
3. Trace login from Flutter through `/api/v1/auth/token`.
4. Trace borrower creation through presentation, Riverpod, repositories, FastAPI, and PostgreSQL.
5. Create a loan and inspect the backend-generated installment schedule.
6. Preview and confirm a payment; compare the persisted allocation with its receipt.
7. Open the loan statement and follow its running balance.
8. Reverse a payment and confirm the original ledger row remains present.
9. Inspect dashboard and financial-report projections.
10. Queue an offline mutation and follow `/api/v1/sync/drain` after reconnecting.
11. Run Flutter, backend, and Postman tests.

## Project map

```text
lending_nelson/
├── lib/                    Flutter application
│   ├── app/                App shell, theme, and routing
│   ├── core/               Networking, database, and security
│   └── features/           Feature-oriented UI, domain, and data code
├── backend/
│   ├── app/
│   │   ├── routers/        HTTP boundary
│   │   ├── schemas/        Request and response contracts
│   │   ├── services/       Business and financial rules
│   │   └── models/         PostgreSQL mappings
│   ├── alembic/            Database migrations
│   └── tests/              Backend tests
├── postman/                Complete API regression suite
├── test/                   Flutter tests
└── docs/                   Architecture, learning, domain, roadmap, history
```

## Core architectural rule

PostgreSQL and backend services are the financial source of truth. Flutter may validate input and display previews returned by FastAPI, but it must not independently calculate authoritative schedules, allocations, balances, receipts, statements, dashboard totals, or reports.

## Study paths

- [Backend Study Guide](BACKEND_STUDY_GUIDE.md)
- [Flutter Study Guide](FLUTTER_STUDY_GUIDE.md)
- [Loan and Payment Rules](../domain/LOAN_AND_PAYMENT_RULES.md)

## Verification exercises

Complete these demonstrations rather than relying only on reading:

- Trigger `401`, refresh authentication, and retry safely.
- Trigger a borrower validation `422` and explain the schema error.
- Repeat an identical loan request ID and show that no duplicate is created.
- Reuse the request ID with changed terms and explain the `409`.
- Confirm payment allocation reconciles exactly to the received amount.
- Reverse a payment and find both original and reversal entries in the statement.
- Compare paginated totals with legacy list endpoints.
- Run the Postman suite from a clean development dataset.

## Safe contribution rules

- Keep HTTP and database operations outside Flutter widgets.
- Keep backend routers thin and business rules in services.
- Use `Decimal`, not binary floating point, for money.
- Add an Alembic migration for PostgreSQL schema changes.
- Preserve immutable financial history through reversals.
- Add tests for success, validation, conflict, and idempotency behavior.
- Never commit `.env`, tokens, passwords, encryption keys, signing keys, databases, or build output.
- Review `git diff` before staging and use focused conventional commits.

## Suggested exercises

1. Add borrower pagination without breaking the existing list endpoint.
2. Add a UI indicator for failed offline-sync queue items.
3. Add a statement export format using the existing backend projection.
4. Add a report filter while keeping calculations inside backend services.
5. Add tests for a new workflow transition rule.
