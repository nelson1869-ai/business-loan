# Changelog Update Process - Lending Nelson

This guide details the procedure for keeping `CHANGELOG.md` accurate and structured.

---

## 📜 Principles of the Changelog

- **Target Audience:** Developers, QA team, and product managers.
- **Goal:** Provide a human-readable list of changes.
- **Reference Standard:** [Keep a Changelog](https://keepachangelog.com/).

---

## 🛠️ Step-by-Step Update Guidelines

### 1. Document Changes Early
- When writing code for a feature, add details of your changes to the root `CHANGELOG.md` under the `[Unreleased]` section.

### 2. Group Actions by Categories
Use the following standardized subheadings:
- `Added` for new features.
- `Changed` for updates to existing logic or UI.
- `Deprecated` for features that will be removed in future versions.
- `Removed` for features that have been removed.
- `Fixed` for bug fixes.
- `Security` to document vulnerability fixes.

### 3. Release Versioning Routine
When a release build is prepared:
1. Rename the `[Unreleased]` heading to the release version (e.g., `## [1.0.0] - 2026-07-18`).
2. Add a new `[Unreleased]` section at the top of the file.
3. Compare local code with the last release tag to ensure no changes were omitted:
   ```powershell
   git log <last-tag>..HEAD --oneline
   ```
