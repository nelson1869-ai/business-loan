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
- **Code Reference Formatting:** When presenting code references, always state the line range and the file link in the header/description text (e.g. `Lines 6-15 in [mock_data_service.dart](...)`). Keep the code block itself clean of any line numbers so it can be easily copied and pasted without prefix cleanup.
- **Documentation & Comments:** Use proper Dart documentation comments (`///`) for all classes, public methods, and top-level providers. Reference symbols inside square brackets (e.g., `[mockDataServiceProvider]`). Reserve double slashes (`//`) for internal step-by-step logic and inline details.
- **Recommendation Prefixing:** When presenting a choice or a list of options to the user, always identify the best course of action by prefixing it with `(Recommended)` and placing it first in the list.

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

---

## 🎮 Interaction Modes

- **Guide Me Mode:** When the user requests "Guide Me Mode", the agent must not modify the codebase directly. Instead, the agent must guide the user step-by-step, presenting only one step at a time. Each step must contain:
  1. **Progress Checklist:** Print the updated task checklist at the beginning of each step so the user can easily see their progress.
  2. **Where to add it:** Clear file link and line range in the text description (keeping the code block itself clean of line numbers for easy copy-pasting).
  3. **How to run/use it:** Any shell commands or execution steps.
  4. **Code with Internal Comments:** Provide the code block containing detailed, step-by-step internal comments (`//`) explaining what the code logic does.
  5. **Visual Architectural Flow:** Present an ASCII diagram showing the file and data relationships, and include it as a comment at the top of the main file. (Ensure all files updated in a step have their individual flow diagrams added as comments at the top).
  6. **Grouped & Layered Imports:** Group and comment Dart imports by their architectural layer (e.g. Core Services, Data Repositories, Domain Models) in code snippets.
  7. **What, Why, and ELI5:** A clear description of what the code is, why it's needed, and a simple "Explain Like I'm 5" (ELI5) explanation.
  8. The agent must wait for the user to confirm completion of the current step before showing the next step.

---

## 🖨️ Printable HTML Learning Document Standards

When creating printable HTML study documents or reference guides:
- **Paper Dimensions & Exact Printable Math:**
  - Standard US Letter Bond Paper Size: `8.5 in × 11.0 in` (`215.9 mm × 279.4 mm` / `612 pt × 792 pt`).
  - Margins: `@page { size: letter portrait; margin: 0.25in 0.30in 0.25in 0.30in; }`.
  - Net Printable Width: `8.5 in - 0.60 in = 7.90 in` (`758 px`).
  - Net Printable Height: `11.0 in - 0.50 in = 10.50 in` (`1008 px` / `10.4 in - 10.5 in` threshold).
- **Dynamic Flexbox Print Engine & Zero Empty Space:** Use CSS `.sheet { width: 8.5in; height: 10.4in; min-height: 10.4in; display: flex; flex-direction: column; justify-content: space-between; page-break-after: always; page-break-inside: avoid; }` so each page automatically stretches top-to-bottom across 1 bond paper sheet with **ZERO empty white space gaps** at the bottom.
- **Dynamic Page Count per Topic:** Document length is NOT fixed to 3 pages. It scales naturally to 1, 2, 3, or more pages based strictly on topic complexity and content depth.
- **Per-Page Custom Styling:** Font sizes, font families, line-heights, card margins, and padding must be tuned independently on a per-page (`.sheet`) basis to fit each page's unique content perfectly.
- **Primary Backend & Database Focus (80-90%):** All study guides must prioritize Postman API collections/specs, FastAPI backend routers/services, and PostgreSQL database schemas/queries, using Flutter UI strictly as the mobile client connection layer.
- **Real Data Travel Trace:** Every guide must include a visual ASCII "Real Data Travel Trace" showing step-by-step value transformations (Postman JSON Request &rarr; FastAPI Pydantic &rarr; Service/Engine &rarr; PostgreSQL SQL rows &rarr; Flutter UI Model).
- **Live Stored SQL Rows Example:** Include sample stored SQL database rows (e.g., formatted ASCII output of `SELECT * FROM table`) alongside ORM model code blocks.
- **Mermaid Visual Flowcharts:** Include interactive or printable Mermaid flowcharts (`flowchart TD`) visualizing client layers, backend services, and database table relationships.
- **Short Inline Study Comments:** Include concise, step-by-step inline comments (`// 1.`, `// 2.`) and ELI5 callout boxes in all code snippets so they are easy to learn from.

