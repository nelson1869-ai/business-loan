# Lending Nelson API Postman Collection

This directory contains the automated Postman test suite for the Lending Nelson FastAPI backend. The collection is maintained against the FastAPI routes, Pydantic schemas, and OpenAPI contract in this repository.

The canonical collection is `lending-nelson-api.json`. The file-based workspace under `collections/Lending Nelson API` remains available for interactive use, but the JSON collection is the complete regression suite.

## Prerequisites

- PostgreSQL configured in `backend/.env`
- The existing virtual environment at `backend/.venv`
- Postman Desktop, Postman CLI, or Node.js with Newman
- Development account: `officer1` / `password123`

The account above is only for local development. Never use it in production.

## Start the backend

From PowerShell:

```powershell
Set-Location D:\Development\lending_nelson\backend
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Verify the API at `http://127.0.0.1:8000/health`.

## Import into Postman

1. Open Postman Desktop.
2. Select **Import**.
3. Choose `postman/lending-nelson-api.json`.
4. Open **Lending Nelson API**.
5. Run the complete collection in its saved order.

No separate environment import is required. The collection contains its own variables and captures generated IDs automatically.

## Run from the command line

With Postman CLI:

```powershell
postman collection run "D:\Development\lending_nelson\postman\lending-nelson-api.json"
```

With Newman:

```powershell
npx --yes newman run "D:\Development\lending_nelson\postman\lending-nelson-api.json"
```

## Collection variables

| Variable | Purpose |
|---|---|
| `baseUrl` | API origin; defaults to `http://127.0.0.1:8000` |
| `accessToken`, `refreshToken` | Captured and rotated by authentication requests |
| `borrowerId`, `loanId`, `draftLoanId`, `paidLoanId` | Captured entity IDs |
| `paymentId`, `reversalId` | Captured ledger IDs |
| `loanRequestId`, `paymentRequestId`, `reversalRequestId` | Dynamically generated idempotency keys |
| `transactionUuid` and `sync*` | Offline synchronization IDs |
| `dateFrom`, `dateTo`, `asOf`, `paymentDate` | Dynamically generated test dates |
| `startDate`, `firstDueDate` | Dynamically generated loan schedule dates |

Reusable entity IDs are captured from API responses. They are not hardcoded.

## Execution order

1. `01 Health`
2. `02 Authentication`
3. `03 Development Setup`
4. `04 Borrowers`
5. `05 Active Loan Creation`
6. `06 Draft Loan Workflow`
7. `07 Loan Pagination`
8. `08 Payment Preview and Confirmation`
9. `09 Payment Pagination`
10. `10 Receipt Projection`
11. `11 Loan Statement`
12. `12 Dashboard`
13. `13 Financial Reports`
14. `14 Offline Sync`
15. `15 Payment Reversal`
16. `16 Negative Tests`
17. `99 Cleanup`

## Destructive-data warning

The collection resets and seeds development data during setup. `99 Cleanup` resets it again after verification. Run this collection only against a disposable development database.

Do not run cleanup before receipt, statement, dashboard, report, sync, and reversal requests have completed.

## Expected successful result

A complete verified run executes:

- 68 requests
- 124 assertions
- 0 failed requests
- 0 failed assertions

The suite covers authentication, borrower CRUD, loan workflows, pagination, payments, financial reconciliation, receipts, statements, dashboard projections, reports, offline synchronization, reversals, and negative cases.

## Troubleshooting

- `401 Unauthorized`: run Login first and confirm the development user exists.
- `404 Not Found`: run dependent creation requests first and ensure cleanup has not reset the data.
- `409 Conflict`: this can be expected for conflicting idempotency keys, duplicate reversals, duplicate national IDs, and invalid workflow transitions. Check the assertion name and response detail.
- `422 Unprocessable Content`: verify camelCase field names, UUIDs, dates, enum values, and pagination bounds. Valid pagination requires `offset >= 0` and `1 <= limit <= 200`.
- `500 Internal Server Error`: inspect the Uvicorn traceback and PostgreSQL connection. Do not weaken a correct assertion to conceal a backend defect.

For a reproducible run, always start from `01 Health` and allow the development setup requests to create a clean dataset.

## Known workflow limitation

The collection verifies that completing a loan with an outstanding balance returns `409`. A successful `complete` transition cannot currently be produced naturally because full payoff changes the loan status directly to `Paid`.
