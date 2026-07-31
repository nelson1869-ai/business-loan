# Contribution & Development Workflow Guidelines

This document defines the standard development workflow and release procedures for the **Lending Nelson** platform.

---

## 🔄 Development Cycle

```text
feature branch
  ↳ local verification
    ↳ push branch
      ↳ pull request
        ↳ CI checks
          ↳ code review
            ↳ merge to main
```

### 1. Branch Naming Conventions
Always create feature branches off the latest `main` branch using descriptive prefixes:

- `feat/feature-name` (e.g. `feat/borrower-due-date-filter`)
- `fix/bug-description` (e.g. `fix/sqlite-upgrade-v11-fk`)
- `docs/topic` (e.g. `docs/update-architecture-diagrams`)
- `refactor/area` (e.g. `refactor/sync-queue-lease`)
- `security/hardening-topic` (e.g. `security/webhook-secret-validation`)

### 2. Conventional Commits
Write concise commit messages adhering to the standard format:

```text
feat(offline-sync): implement client-side idempotency retry header
fix(database): enforce SQLite foreign key pragma on database open
docs(readme): update SQLite version reference to v11
test(backend): add test for production webhook secret requirement
```

---

## 🧪 Local Verification Workflow

Before pushing any branch or opening a pull request, run all automated checks locally.

### Flutter Checks

```powershell
# 1. Analyze code for lint rules and static issues
flutter analyze

# 2. Verify code formatting
dart format --output=none --set-exit-if-changed lib test

# 3. Run complete test suite (unit, widget, database migration, parity)
flutter test
```

### Backend Checks

```powershell
Set-Location backend

# 1. Check Python dependencies consistency
.\.venv\Scripts\python.exe -m pip check

# 2. Lint backend code with Ruff
.\.venv\Scripts\python.exe -m ruff check .

# 3. Run unit and integration tests with pytest
.\.venv\Scripts\python.exe -m pytest

# 4. Check Alembic migration consistency
.\.venv\Scripts\python.exe -m alembic check
```

---

## 🔒 Recommended GitHub Branch Protection Settings

To ensure production stability on the public GitHub repository, configure the following rules on the `main` branch:

1. **Require a pull request before merging:**
   - Require at least 1 approval.
   - Dismiss stale pull request approvals when new commits are pushed.
2. **Require status checks to pass before merging:**
   - Require branch to be up to date before merging.
   - Required checks:
     - `CI / Flutter Quality & Tests`
     - `CI / Backend Quality & Tests`
     - `CI / Security Scans & Dependency Review`
3. **Restrict branch modifications:**
   - Block force pushes (`--force`).
   - Block branch deletion.
   - Require conversation resolution before merging.
