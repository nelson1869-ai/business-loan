# Infrastructure Deployment Plan - Lending Nelson

This plan covers environment separation, secrets control, database migrations, and CI/CD pipelines. Backend deployment technology remains undecided.

---

## 🌐 Environment Isolation Guidelines

The system enforces strict separation between environment levels:

| Environment | Database Target | Purpose | DNS Endpoint (TBC) |
| --- | --- | --- | --- |
| **Development** | Dev postgres database | Sandbox for writing new code | `dev-api.lendingnelson.com` |
| **Staging** | Staging clone database | Pre-release QA regressions | `staging-api.lendingnelson.com` |
| **Production** | Prod replication database | Live operations | `api.lendingnelson.com` |

---

## 🔒 Configuration & Secrets Control

- **Configuration Files:** Environment parameters (e.g., API timeout lengths, debug mode triggers) are stored in standard YAML configuration files.
- **Secrets Management:** Keystore passwords, email gateway keys, and database passwords must never be stored in plain text files. They are injected at deployment time using secure vaults (e.g., GCP Secret Manager, Vault, or GitHub Actions Secrets).

---

## 🔄 Database Migrations & Releases

- **Incremental Schema Scripts:** All database changes must be executed using versioned schema migration files (e.g., Flyway, Liquibase, or native framework migrations).
- **Zero-Downtime Deployments:** Schema modifications should be backward compatible to ensure older mobile clients continue to function during deployment rollouts.
- **Database Backup:** Run a full snapshot backup before applying migrations to production databases.

---

## 🚀 CI/CD Pipeline Workflow

```
  Push Event ➔ Run static analysis ➔ Run test suites ➔ Build signed binaries ➔ Deploy API
```

1. **Static Quality Check:** Every push to a repository branch triggers linter rules checking.
2. **Automated Testing:** All unit and integration test suites must pass before merge approvals are granted.
3. **Build Delivery:** Approved PRs compile signed artifacts, distributing debug packages to Firebase App Distribution automatically.
