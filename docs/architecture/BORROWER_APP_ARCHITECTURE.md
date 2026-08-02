# Borrower App Architecture Documentation

## Architecture Overview
The **Borrower Mobile Client** (`apps/borrower_mobile`) follows **Feature-First Clean Architecture** with **Riverpod** state management.

```text
apps/borrower_mobile/lib/
├── app/                  # App configuration & GoRouter setup
├── core/                 # Shared utilities, API client, secure storage, auth interceptors
└── features/
    ├── authentication/   # Login, OTP verification
    ├── dashboard/        # Borrower overview dashboard & caching
    ├── loans/            # Loan list, status filter, loan detail & local cache
    ├── notifications/    # Notifications placeholder
    ├── payments/         # Payments placeholder
    └── profile/          # Profile placeholder
```

## Security & Data Privacy
1. **Single Source of Truth**: The app displays authoritative ledger data calculated on the FastAPI backend. It does not perform local financial calculations.
2. **Encrypted Secure Storage**: Auth tokens and cached loan data are stored using `FlutterSecureStorage`.
3. **Cache Isolation**: All local cache keys are scoped by `borrowerAccountId` (e.g., `cached_loans_list_<account_id>_<status>`). Logging out purges or isolates cached data so account switching never exposes stale borrower data.
4. **Offline Mode**: When offline, cached views display an explicit warning banner showing the last-updated timestamp.

## Routing
Managed by `GoRouter`:
* `/login` - Borrower activation / login
* `/verify` - OTP code verification
* `/home` - Borrower dashboard screen
* `/loans` - Paginated borrower loan list screen
* `/loans/:loanId` - Detailed read-only loan overview screen
