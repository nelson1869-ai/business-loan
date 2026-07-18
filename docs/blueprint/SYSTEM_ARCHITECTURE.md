# System Architecture Specification

This blueprint documents the recommended Flutter architecture for the `lending-nelson` mobile client. It is built upon the principles of **Clean Architecture** and structured **Feature-First**.

---

## 🏗️ Layered Architecture (Clean Architecture)

The codebase is separated into four distinct architectural layers, maintaining a strict unidirectional dependency rule: **Presentation ➔ Application ➔ Domain ◄─ Data**.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            Presentation Layer                               │
│  - Widgets (UI Layouts)                                                     │
│  - State Notifiers / Riverpod Providers (UI State Management)               │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                             Application Layer                               │
│  - Use Cases (Business workflows orchestration)                            │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                               Domain Layer                                  │
│  - Entities (Core business data models)                                     │
│  - Repository Interfaces (Contracts for data operations)                    │
│  - Value Objects & Validators                                               │
└──────────────────────────────────────▲──────────────────────────────────────┘
                                       │ (Implements)
                                       │
┌──────────────────────────────────────┴──────────────────────────────────────┐
│                                Data Layer                                   │
│  - Repository Implementations                                               │
│  - Data Sources (Remote Dio Client, Local Database Client)                  │
│  - DTO Models (JSON serialization & parsing)                                │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1. Presentation Layer
- **Widgets:** Lean layout widgets focusing solely on presentation.
- **Controllers/Notifiers:** Riverpod `Notifier` or `AsyncNotifier` classes that handle UI state and bridge it to Application use cases. No business calculations are performed here.

### 2. Application Layer
- **Use Cases:** Encapsulate single-responsibility business workflows (e.g., `SubmitLoanApplication`, `SyncPaymentQueue`).

### 3. Domain Layer
- **Entities:** Simple Dart classes representing core concepts (e.g., `Loan`, `Borrower`). Completely independent of packages or database annotations.
- **Repository Interfaces:** Declarative contracts defining what data is needed, not how it is fetched.

### 4. Data Layer
- **DTOs (Data Transfer Objects):** Subclasses of domain entities (or separate classes) containing serialization logic (e.g., `fromJson`, `toJson`).
- **Repositories:** Concrete implementations of Domain repository interfaces. They manage fetching from local SQLite cache versus calling the backend API.
- **Data Sources:** Low-level clients for remote HTTP calls (Dio) or local database clients.

---

## 🛠️ Technology Integration & Core Patterns

### State Management & Dependency Injection (Riverpod)
- All repositories, data sources, use cases, and controllers are exposed via Riverpod providers.
- Avoid global variables or direct manual instantiation to simplify testing and mocking.

### Routing & Navigation (GoRouter)
- Declarative routing using [GoRouter](https://pub.dev/packages/go_router) with strict path routing.
- Deep linking support for opening specific loans or borrower profiles directly from notifications.

### API Communication (Dio)
- Configured with global interceptors to handle:
  - Injection of authentication bearer tokens.
  - Automatic token refresh logic.
  - Consistent error parsing (converting raw errors into application-level custom exceptions).
  - Timeout and retry limits.

### Local & Secure Storage
- **Flutter Secure Storage:** Used to encrypt and store sensitive tokens (auth credentials, refresh tokens).
- **Shared Preferences:** Used for non-sensitive device configurations (theme preferences, cache timestamps).
- **Local SQLite Cache (Isar/Hive/Floor):** Used as the offline database (choice TBC).

---

## 🛜 Offline-First Architecture

* **Repository Synchronization Strategy:**
  - Queries fetch first from the local database to guarantee instant response. A background process updates the cache from the server.
  - Writes are written to the local database, and a sync event is added to a persistent **Offline Synchronization Queue**.
* **Idempotent Operations:** All mutations generated offline use unique transaction UUIDs to prevent duplicate processing on the server.

---

## 🧪 Testing Boundaries

- **Unit Tests:** Cover pure logic: domain entity validation rules, financial interest calculations, use cases.
- **Widget Tests:** Verify UI behavior using mocked Riverpod providers to avoid real database/API calls.
- **Integration Tests:** End-to-end flows using a local mock server to ensure full interaction matches expectations.
