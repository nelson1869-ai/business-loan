# Definition of Done (DoD) - Lending Nelson

A task is considered complete and ready for code review only when it satisfies all of the criteria in the following checklist.

---

## 📋 Definition of Done Checklist

### 1. Requirements & Design
- [ ] Task requirements are understood, and edge cases are identified.
- [ ] Business and lending rules are confirmed and implemented.

### 2. Implementation & Code Quality
- [ ] All code conforms to [Coding Standards (docs/development/CODING_STANDARDS.md)](file:///d:/Development/lending_nelson/docs/development/CODING_STANDARDS.md).
- [ ] No business calculations or raw API requests exist directly inside widgets.
- [ ] Code is formatted using `dart format`.
- [ ] Static analysis compiles with no errors or warnings (`flutter analyze`).

### 3. Verification & Testing
- [ ] Unit tests are written for all new calculations and validation helpers.
- [ ] Automated tests compile and pass successfully (`flutter test`).
- [ ] Manual verification is completed on an emulator or physical device.
- [ ] Error conditions (e.g., duplicate submissions, lack of network connection) are handled and verified.

### 4. Security & Compliance
- [ ] No private keys, passwords, or credentials are hardcoded or committed.
- [ ] Personally Identifiable Information (PII) is encrypted at rest in local tables.
- [ ] Actions are logged in the user audit trail if they mutate data.

### 5. Documentation
- [ ] All new components or APIs are documented.
- [ ] Project roadmap files are updated.
- [ ] Changes are added to `CHANGELOG.md` under the `[Unreleased]` section.

### 6. Git & Integration
- [ ] Working directory is checked for untracked garbage files (`git status`).
- [ ] Changes are committed using standard prefixes (e.g., `feat:`, `fix:`).
- [ ] Code is pushed to GitHub, and the CI build passes successfully.
