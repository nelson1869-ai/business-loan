# Agent Guidelines & Rules — Lending Nelson (Production)

This file defines the mandatory rules, architecture, coding standards, security requirements, and release policies for AI coding agents working on the **Lending Nelson** project.

These rules take precedence over convenience. Never sacrifice security, maintainability, or production quality.

---

# 🏗️ Project Architecture

## Platform

* Flutter (Stable)
* Android Production Application
* Package: `com.nelson.lending`

Future platforms:

* Web Admin
* Windows Desktop

---

## Architecture

Use **Feature-First Clean Architecture**.

Every feature must be separated into:

* presentation
* domain
* data

Business logic must never leak across layers.

---

## Navigation

Use **GoRouter** only.

No Navigator.push unless absolutely required.

---

## State Management

Use **Riverpod** with code generation (`@riverpod`) whenever appropriate.

UI reads state only.

Controllers and Notifiers perform actions.

---

## Networking

Use **Dio**.

Requirements:

* JWT Authentication
* Interceptors
* Automatic refresh handling (if implemented)
* HTTPS only in production
* Certificate pinning when enabled

---

## Local Storage

Use:

* Flutter Secure Storage
* Encrypted SQLite/Isar

Never store sensitive information in plaintext.

---

# 📜 Coding Standards

## Business Logic

Never place:

* loan calculations
* interest calculations
* penalties
* validation
* business rules

inside Widgets.

Only Domain or Application layers may perform business calculations.

---

## Widgets

Widgets must never:

* call APIs
* execute SQL
* perform repository work
* contain business calculations

Widgets only display state and dispatch user actions.

---

## File Size

Recommended:

* Widgets: under 200 lines
* Controllers: focused and single responsibility
* Services: one responsibility only

Split large files.

---

## Null Safety

Maintain strict null safety.

Avoid `!` unless the value has already been validated.

---

## Documentation

Public APIs must use Dart documentation comments (`///`).

Document:

* classes
* providers
* repositories
* public methods

Use `//` only for implementation details.

---

## Formatting

Before every commit:

* `dart format lib test`
* `flutter analyze`
* `flutter test`

All must pass.

---

# 🔒 Security Requirements

## Secrets

Never commit:

* API keys
* JWT secrets
* passwords
* Firebase credentials
* Google service accounts
* signing keystores
* `key.properties`
* `.env`

Use secure environment configuration.

---

## PII Protection

Encrypt borrower information stored locally, including:

* names
* phone numbers
* government IDs
* addresses

Never expose sensitive information in logs.

---

## Logging

Never log:

* passwords
* JWTs
* borrower names
* payment details
* IDs
* secrets

Sensitive values must be redacted.

---

## Auditing

Every data mutation must create an audit log entry.

Audit records must be immutable.

---

# 🚫 Development Feature Policy

Development-only functionality must never exist in production.

Do not add or restore:

* Seed database
* Reset database
* Delete-all tools
* Debug pages
* Developer menu
* Queue inspector
* Fake borrower generators
* Diagnostic endpoints
* Test-only APIs

These belong only in temporary development branches, not in the production repository.

---

# 🌐 Production Deployment

The application is intended to be:

* Public GitHub repository
* Self-hosted backend (Windows PC)

Production requirements:

* HTTPS
* Strong JWT secret
* Secure CORS configuration
* No debug mode
* PostgreSQL not publicly exposed
* Windows Defender Firewall configured
* Regular encrypted backups
* Service auto-restart
* Log rotation

---

# 📱 Android Release

Release builds must:

* use production signing
* never use debug signing
* never include localhost URLs
* never include hardcoded credentials
* disable cleartext traffic
* build successfully with a local, uncommitted keystore

Never commit:

* keystore files
* `android/key.properties`

---

# 🌿 Git Standards

## Branches

* `main` is always production-ready.

Development work should be completed in feature branches.

---

## Commits

Use conventional commits:

* `feat:`
* `fix:`
* `docs:`
* `refactor:`
* `test:`
* `chore:`
* `security:`

Each commit should represent one logical change.

---

# ✅ Quality Gates

Before considering any task complete, verify:

* Flutter analyzer passes
* Flutter tests pass
* Backend tests pass
* Formatting passes
* No broken imports
* No dead code
* No unused files
* No committed secrets
* No known dependency vulnerabilities (when scanning tools are available)

Never claim success unless checks were actually executed.

---

# 🤖 Agent Behavior

When modifying this repository:

* Preserve the existing architecture.
* Avoid unnecessary refactoring.
* Do not introduce breaking changes without justification.
* Remove dead code rather than hiding it.
* Prefer secure defaults.
* Explain significant architectural decisions.
* Only report results that were actually verified.

When offering multiple solutions, always present the **recommended** option first and explain any trade-offs.

The goal is to keep this repository production-ready, secure, maintainable, and suitable for public GitHub publication.
