# Architecture Decision Records (ADR) - Lending Nelson

This document logs key technology selection decisions, including proposed, accepted, and undecided architectural choices.

---

## 🏛️ Decisions Registry

### ADR 1: Client Framework Selection
* **Decision:** Use **Flutter** as the cross-platform application framework.
* **Rationale:** Direct native rendering, rich UI components, and strong support for Android (primary target) with easy compilation to Web/Windows in later phases.
* **Status:** **Accepted**

### ADR 2: Target Device Operations
* **Decision:** Target **Android** as the primary operating platform.
* **Rationale:** Field operations leverage affordable Android tablets/smartphones.
* **Status:** **Accepted**

### ADR 3: Directory and Architecture Structure
* **Decision:** Implement a **Feature-First Clean Architecture**.
* **Rationale:** Separates business logic from UI layouts. Feature directories group all presentation, domain, and data files, which scales better for multi-person teams.
* **Status:** **Accepted**

### ADR 4: State Management & Injection
* **Decision:** Use **Riverpod** for state notification and dependency injection.
* **Rationale:** Provides compile-safe DI, eliminates context dependency for provider reads, and simplifies unit test mocking.
* **Status:** **Accepted**

### ADR 5: Client Route Management
* **Decision:** Use **GoRouter** for application routing.
* **Rationale:** Declarative route configuration and seamless deep-linking integration.
* **Status:** **Accepted**

### ADR 6: Network Communication Client
* **Decision:** Use **Dio** as the HTTP client.
* **Rationale:** Built-in interceptors support, certificate pinning, and easy request retry adapters.
* **Status:** **Accepted**

### ADR 7: Sensitive Storage Strategy
* **Decision:** Use **Flutter Secure Storage** (Keystore/Keychain) for authentication secrets.
* **Rationale:** Hardware-backed encryption protects critical access/refresh tokens.
* **Status:** **Accepted**

### ADR 8: Development Environment Setup
* **Decision:** Standardize on **PowerShell** for terminal scripting and **Antigravity** as the main editor.
* **Rationale:** Tailored developer commands workspace.
* **Status:** **Accepted**

### ADR 9: Backend Technology Choice
* **Decision:** **Undecided**
* **Alternatives:** Node.js (Express/NestJS), Go (Fiber), Python (FastAPI), or Firebase.
* **Status:** **Undecided**

### ADR 10: Database Technology Choice
* **Decision:** **Undecided**
* **Alternatives:** PostgreSQL (via Cloud SQL/AlloyDB), SQLite (local SQLCipher), or Isar.
* **Status:** **Undecided**
