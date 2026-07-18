# Phase Execution Template - Lending Nelson

This template defines the step-by-step procedure required to execute and complete any development phase in the roadmap.

---

## 📋 Phase Execution Checklist

### 1. Objective
* State the specific goal and target features of the phase.

### 2. Repository Inspection
* Run `git status` to ensure a clean working directory.
* Run `git pull --rebase origin main` to fetch recent changes.
* Run `flutter analyze` and `flutter test` to ensure base health.

### 3. Implementation Plan
* Document the components, models, and UI changes to be built.

### 4. Files to Create
* List new files to add (e.g., repository interfaces, notifier classes, widget layouts).

### 5. Files to Modify
* List existing files to update (e.g., config mappings, database migrations).

### 6. Dependencies
* Note if the phase requires new pub packages or backend REST updates.

### 7. Data Model Impact
* Detail database schema additions or model changes.

### 8. Security Impact
* Identify inputs to validate, encryption details, or new permissions.

### 9. Tests
* **Unit Tests:** Define logic assertions (e.g., verification helper validations).
* **Widget Tests:** Set up mock states to verify rendering.

### 10. Manual Verification
* List manual steps to verify using local emulator/device.

### 11. Documentation Update
* Update the phase status in `docs/planning/ROADMAP.md` and check off items in `docs/planning/TODO.md`.
* Document updates in `CHANGELOG.md`.

### 12. Git Commit
* Format commit messages using standard prefixes (e.g., `feat: Add borrower screen`).

### 13. Push & Repository Review
* Push to GitHub and check CI status.

### 14. Completion Checklist
* Final check of compiler warnings, code formatter, and status dashboard.
