# Borrower Mobile Application Architecture

## Architectural Boundaries

The **Lending Nelson** platform maintains a strict separation between internal officer operations and external borrower self-service access:

- **Officer Mobile Application (`/`)**: Internal Android application for loan officers, managing origination, collection tasks, manual payments, and borrower verification.
- **Borrower Mobile Application (`apps/borrower_mobile/`)**: Dedicated Flutter application for borrowers, providing access to loan schedules, statements, payment history, and profile details.

```text
business-loan/
├── apps/
│   ├── officer_mobile/ (Planned migration target)
│   └── borrower_mobile/ (Implemented Phase 1)
├── backend/
│   └── app/
│       ├── core/
│       └── features/
│           ├── borrower_portal/ (/api/v1/client)
│           └── ... (Officer routes /api/v1/*)
└── docs/
```

## Core Principles

1. **Backend Authoritative Financial Logic**: All financial totals, loan schedules, payment allocation, and interest accruals are calculated strictly on the backend. The borrower mobile client never independently calculates authoritative figures.
2. **Feature-First Clean Architecture**: Presentation, domain, and data layers are cleanly isolated within `apps/borrower_mobile/lib/features/`.
3. **Dedicated Authentication Boundary**: Borrower accounts use `aud: borrower-app` and cannot authenticate against officer management routes.
