# Agent Guidelines & Rules - Lending Nelson

This file defines the project-specific rules, architectural boundaries, coding standards, and security constraints for AI coding agents collaborating on the `lending-nelson` codebase.

---

## 🏗️ Project Architecture & Technologies

All code modifications must conform to the following architectural design:

- **Framework & Target:** Flutter (Stable channel) targeting Android mobile clients (Package ID: `com.nelson.lending`). Web Admin and Windows platforms are planned for future phases.
- **Folder Structure:** **Feature-First + Clean Architecture** under `lib/`. Feature directories are modular and partitioned into `presentation/`, `domain/`, and `data/` layers.
- **Routing:** [GoRouter](https://pub.dev/packages/go_router) for route mapping and navigation.
- **State Management & DI:** [Riverpod](https://pub.dev/packages/flutter_riverpod) using code generation (`@riverpod`) where possible.
- **Network client:** [Dio](https://pub.dev/packages/dio) with custom JWT interceptors and SSL certificate pinning.
- **Local Storage:** [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage) for JWT and encryption keys; encrypted SQLite/Isar database for offline caching.

---

## 📜 Development & Coding Rules

- **No Business Logic in Widgets:** All business calculations (e.g., interest, late fees, amortization) belong strictly in pure domain calculators. Never perform calculations directly inside a Widget `build` method.
- **No Direct API/DB Calls from Widgets:** Widgets are strictly for presentation. They must read state from Riverpod Notifier Providers and dispatch actions to Notifier Controllers or Application Use Cases.
- **Widget Code Size Limit:** Individual UI Widget files must be kept clean and concise (recommended limit: < 200 lines of code).
- **Null Safety:** Enable strict type checks. Avoid using the force-unwrap operator (`!`) without explicit null verification.
- **Dart Formatter:** Always run `dart format lib test` before committing.
- **Lint Checks:** `flutter analyze` must pass with zero warnings or errors.
- **Test Executions:** All unit, widget, and integration tests must pass cleanly (`flutter test`).

---

## 🔒 Security Constraints

- **No Hardcoded Secrets:** Keystore credentials, Firebase client secrets, API passwords, and third-party keys must never be hardcoded or committed to source control. Use environment configuration (`--dart-define`).
- **PII Protection:** Borrower Personally Identifiable Information (Name, Phone, National ID) must be encrypted at rest when stored in local tables.
- **Log Sanitation:** Ensure application logs redact sensitive inputs (passwords, full National IDs, JWT tokens).
- **Immutable Auditing:** Data mutations must write corresponding logs to the local `AuditLog` table.

---

## 🌿 Git & Commit Standards

- **Branch Policy:** `main` is the stable branch. Submit changes via PRs.
- **Commit Messages:** Follow standard prefixes:
  - `feat:` for new features
  - `fix:` for bug fixes
  - `docs:` for documentation updates
  - `refactor:` for code refactoring
  - `test:` for writing tests
  - `chore:` for build/dependency updates
  - `security:` for encryption/security hardening
- **Incremental Commits:** Group commits into small, single-responsibility changes.
