# Project Directory Structure - Lending Nelson

This document describes the future feature-first structure for the `lib/` directory.

---

## 📂 The Directory Tree

```
lib/
├── app/                  # Application startup configurations and router
├── core/                 # Shared domain rules and device interfaces
├── shared/               # Reusable UI widgets and presentation helpers
└── features/             # Business capability spaces (feature-first groups)
    ├── authentication/   # Staff login, pin locks, token secure storage
    ├── dashboard/        # Main landing view, daily stats counters
    ├── borrowers/        # Borrower list, details profile, and forms
    ├── loan_products/    # Product specifications display
    ├── loan_applications/# New application forms, document scanner layout
    ├── loans/            # Approved active contract displays
    ├── repayments/       # Amortization installments schedules tables
    ├── payments/         # Payment collection logs, receipts export
    ├── collections/      # Delinquency lists, collection notes
    ├── documents/        # PDF file attachments viewer
    ├── notifications/    # Message history lists
    ├── reports/          # Branch performance figures charts
    └── settings/         # Theme toggles, language, synchronization controls
```

---

## 🔍 Directory Descriptions

### 1. `lib/app/`
- Contains the main application setup classes, navigation maps (`app_router.dart`), and global style tokens (`app_theme.dart`).

### 2. `lib/core/`
- Holds framework-agnostic interfaces. This includes custom exception formats, HTTP network base clients, local database wrappers, and core extensions.

### 3. `lib/shared/`
- Exposes widgets used across multiple features, such as custom buttons, loading spinners, input fields, and popup dialogs.

### 4. `lib/features/`
- Every folder in this directory represents a standalone business module. Each feature folder is structured internally using Clean Architecture layers:
  ```
  features/borrowers/
  ├── presentation/      # Widgets, Screen layouts, Controllers
  ├── domain/            # Borrower entities, Repository interfaces
  └── data/              # Borrower models (DTOs), Repository impls, API sources
  ```
- Developers working on one feature do not depend on the implementation details of other features, making the project highly modular.
