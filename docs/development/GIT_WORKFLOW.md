# Git Workflow - Lending Nelson

This document details the source control practices required to keep the repository history clean and stable.

---

## 🌿 Branching Policy

- **`main` Branch:** The central, stable branch. Code on `main` must compile and pass all tests. Direct pushes to `main` are restricted on production repositories; submit changes via Pull Requests (PRs).
- **Feature Branches:** Use descriptive names prefixed by change type:
  - `feat/borrower-onboarding`
  - `fix/schedule-interest-math`
  - `docs/setup-guide`

---

## 🔨 Commit Standards

### 1. Small, Focused Changes
- Commit changes incrementally. Do not bundle multiple unrelated features into a single, massive commit.
- A commit should represent a single logical change (e.g., adding an entity model, fixing a validation regex, or updating a UI button layout).

### 2. Message Formats
Every commit must begin with a standardized prefix followed by a concise description:

- **`feat:`** A new feature (e.g., `feat: implement login screen`)
- **`fix:`** A bug fix (e.g., `fix: correct penalty calculation rounding error`)
- **`docs:`** Documentation changes only (e.g., `docs: generate api endpoint catalog`)
- **`refactor:`** Code modifications that neither fix bugs nor add features (e.g., `refactor: clean up riverpod login providers`)
- **`test:`** Adding or updating tests (e.g., `test: add borrower form validation unit tests`)
- **`chore:`** General maintenance, dependency updates (e.g., `chore: bump dio version to 5.4.0`)
- **`build:`** Build system changes (e.g., `build: update app gradle sdk targets`)
- **`ci:`** Integration workflow changes (e.g., `ci: configure github actions build workflow`)
- **`security:`** Security improvements (e.g., `security: encrypt local SQLite cache file`)

---

## 🔄 Daily Workflow Routines

### Pull-Before-Work
Before beginning work on any branch, fetch the latest code from `main` to prevent merge conflicts:
```powershell
git checkout main
git pull --rebase origin main
```

### Pre-Commit Checklist
Run these commands locally prior to creating a commit:
1. **Format Code:** `dart format lib test`
2. **Static Analysis:** `flutter analyze`
3. **Run Test Suites:** `flutter test`

### Files to Exclude
- Never commit generated build outputs (`build/`), local settings (`.vscode/`), dependency logs (`.dart_tool/`), or configuration properties with local secrets (`android/key.properties`).
- Check your `.gitignore` to ensure these files remain untracked.
