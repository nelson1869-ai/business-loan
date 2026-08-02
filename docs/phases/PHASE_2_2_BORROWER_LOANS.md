# Phase 2.2 — Borrower Loan List and Loan Detail Report

## Status: Fully Implemented & Verified

### Delivered Capabilities
1. **Backend Endpoints**:
   - `GET /api/v1/client/loans?status=active&offset=0&limit=20`
   - `GET /api/v1/client/loans/{loanId}`
2. **Borrower Ownership Guard**:
   - Enforces `Loan.borrower_id == current_account.borrower_id`.
   - Returns `404 Not Found` for loans owned by another borrower.
   - Rejects officer tokens with `401 Unauthorized`.
3. **Flutter Borrower Mobile Screens**:
   - **Loans List Screen (`/loans`)**: Status filter chips (`All`, `Active`, `Overdue`, `Paid`, `Cancelled`), pull-to-refresh, skeleton loader, error retry view, offline mode banner.
   - **Loan Detail Screen (`/loans/:loanId`)**: Financial summary, loan terms, next payment preview, offline mode banner.
4. **Offline Cache & Cache Isolation**:
   - Stores encrypted JSON in `FlutterSecureStorage` scoped by `borrowerAccountId`.
   - Renders `Offline Mode • Displaying cached loans from...` banner when offline.
5. **Quality Gates**:
   - Backend tests: 190/190 passed (`pytest -ra`).
   - Secret safety: 1/1 passed (`test_secret_safety.py`).
   - Code formatting: 0 ruff errors (`ruff check .` & `ruff format --check .`).
   - Alembic schema drift: 0 drift (`alembic check`).
   - Borrower Mobile Flutter: 0 issues (`flutter analyze`), 27/27 passed (`flutter test`).
   - Debug APK: Built cleanly (`build/app/outputs/flutter-apk/app-debug.apk`).
