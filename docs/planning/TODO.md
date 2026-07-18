# Project TODO Checklist - Lending Nelson

This checklist tracks actionable tasks across all implementation phases. Only verified work is marked completed.

---

## 🏁 Phase 0 & 1: Repository, Setup & Blueprints (Current)

- [x] Initialize Flutter project.
- [x] Configure Android package ID to `com.nelson.lending` in `build.gradle.kts`.
- [x] Initialize Git repository.
- [x] Configure GitHub remote to `https://github.com/nelson1869-ai/business-loan`.
- [x] Push initial codebase.
- [x] Verify static code analysis passes (`flutter analyze`).
- [x] Verify starter test suite passes (`flutter test`).
- [x] Write architectural blueprints, security policies, and domain designs (Phase 1 documentation).

---

## 🛠️ Phase 2: Flutter Foundation

- [x] Add `flutter_riverpod` to `pubspec.yaml`.
- [x] Add `go_router` to `pubspec.yaml`.
- [x] Add `dio` to `pubspec.yaml`.
- [x] Add `flutter_secure_storage` to `pubspec.yaml`.
- [x] Add `shared_preferences` to `pubspec.yaml`.
- [ ] Initialize local storage database dependencies (Isar/SQLite).
- [x] Configure `analysis_options.yaml` with strict linter rules.

---

## 🎨 Phase 3: Design System & Navigation

- [ ] Define corporate color palettes and fonts in UI theme.
- [ ] Design shared buttons, input fields, and dialog boxes.
- [ ] Implement main GoRouter routing map.
- [ ] Set up default loading, error, and splash screens.

---

## 🔒 Phase 4: Authentication & Authorization

- [ ] Create secure JWT login page.
- [ ] Implement Auth State Notifier with Riverpod.
- [ ] Add Dio token interceptor to inject JWT into request headers.
- [ ] Set up Token Refresh mechanism.
- [ ] Implement PIN/Biometric lock overlay.

---

## 🧑 Phase 5: Borrower Management

- [ ] Create borrower list and detail screens.
- [ ] Implement Borrower Registration Form.
- [ ] Write validations (National ID, Date of Birth >= 18).
- [ ] Set up local SQLite cache for borrower records.

---

## 📦 Phase 6: Loan Product Configuration

- [ ] Design loan product details screen.
- [ ] Fetch product constraints (interest rates, terms limits) from server.
- [ ] Cache products locally for offline applications.

---

## 📝 Phase 7: Loan Application Workflow

- [ ] Build multi-step Loan Application Form.
- [ ] Add guarantor registration layout.
- [ ] Add attachment selector (for uploading documents).
- [ ] Store application drafts locally.

---

## ⚖️ Phase 8: Approval & Disbursement

- [ ] Implement manager review screens.
- [ ] Set up disbursement details form.
- [ ] Block active state changes until disbursement details are saved.

---

## 📅 Phase 9: Repayment Schedules

- [ ] Implement calculations for flat/declining interest repayments.
- [ ] Write mathematical unit test suites verifying payments schedules.
- [ ] Build schedule installment table UI.

---

## 💵 Phase 10: Payments & Receipts

- [ ] Build Cash Repayment entry form.
- [ ] Implement unique transaction UUID generation.
- [ ] Create printable/shareable PDF payment receipts.

---

## 🚨 Phase 11: Penalties & Collections

- [ ] Write overdue status checker.
- [ ] Implement penalty calculator based on grace periods.
- [ ] Add collections entry logs.

---

## 📁 Phase 12: Documents & Notifications

- [ ] Configure file storage directories.
- [ ] Hook up notifications webhook dispatch triggers.

---

## 🛜 Phase 13: Offline Database & Sync Queue

- [ ] Create `OfflineQueue` local database table.
- [ ] Build network connectivity change listener.
- [ ] Write sequential sync manager.
- [ ] Implement idempotency key injection and duplicate verification.

---

## 📊 Phase 14: Reports & Analytics

- [ ] Create summary cards for Active, Overdue, and Total Disbursed metrics.
- [ ] Render data visualization charts.

---

## 💻 Phase 15 & 16: Web Admin & n8n Workflows

- [ ] Setup web project configurations.
- [ ] Design admin configuration views.
- [ ] Assemble n8n JSON webhook workflow templates.

---

## 🛡️ Phase 17 to 20: Hardening, QA, Release & Launch

- [ ] Enable SQLite DB file encryption.
- [ ] Set up SSL certificate pinning.
- [ ] Conduct final security penetration reviews.
- [ ] Achieve >= 80% code test coverage.
- [ ] Build release App Bundle.
- [ ] Upload to Google Play Store and configure backups.
