# Phase 1.1 — Borrower Portal & Integration Hardening Report

## Overview
Phase 1.1 completes the security hardening and cross-system integration audit across the Borrower Mobile application (`apps/borrower_mobile`), Loan Officer application (root `/`), and FastAPI backend (`backend/`).

## Verification Summary Matrix

| Verification Check | Target Component | Status | Details |
| :--- | :--- | :--- | :--- |
| **Backend Pytest Suite** | FastAPI Backend | **PASS** | 168 passed, 3 skipped (PostgreSQL-only), 0 failed across full test suite. |
| **E2E Borrower Portal Lifecycle** | FastAPI Backend | **PASS** | 17-step end-to-end integration test (`test_borrower_portal_e2e.py`) passed. |
| **Borrower App Unit Tests** | `apps/borrower_mobile` | **PASS** | 8 unit and widget tests passed (`auth_interceptor_test.dart`, `auth_notifier_test.dart`, `login_screen_test.dart`, `widget_test.dart`). |
| **Officer App Unit Tests** | Loan Officer App (root) | **PASS** | Full suite passed. |
| **Flutter Analyzer** | Both Apps | **PASS** | 0 issues found in `apps/borrower_mobile` and root workspace. |
| **Dart Formatter** | Both Apps | **PASS** | All Dart source files formatted according to standard. |
| **Alembic Migrations** | PostgreSQL / DB | **PASS** | Alembic migration HEAD verified. |
| **Secrets & Security Check** | Repository-wide | **PASS** | Zero committed secrets, keys, or dev-only tools. |

## Major Security Enhancements Implemented
1. **Strict 401 Unauthorized for Non-Active Borrower Accounts**:
   - Updated `require_active_borrower_account` dependency in `backend/app/features/borrower_portal/dependencies.py` to raise `401 Unauthorized` with `WWW-Authenticate: Bearer`.
   - Forces immediate client token cleanup and session purge.

2. **Role-Gated Invitation Code Issuance**:
   - Enforced officer/manager/admin role check in `create_client_invitation` endpoint.

3. **Borrower Mobile Concurrency Lock & Bare Dio Refresh**:
   - Refactored `AuthInterceptor` in `apps/borrower_mobile/lib/core/api/auth_interceptor.dart` with a bare `_refreshDio` instance and `Completer<bool>` concurrency lock.
   - Prevents refresh recursion, single-retry enforcement, and non-retryable route exclusions.

4. **Startup Session Validation**:
   - `AuthNotifier` in `apps/borrower_mobile/lib/core/auth/auth_notifier.dart` executes `GET /api/v1/client/me` on launch to validate cached JWT tokens and automatically recover or log out.

5. **Clean UUID Primary Key Generation**:
   - Updated `register_borrower_device` to issue 36-character hex UUID primary keys compatible with SQLite and PostgreSQL schemas.
