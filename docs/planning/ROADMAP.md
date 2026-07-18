# Phased Project Roadmap - Lending Nelson

This document outlines the detailed roadmap for the `lending-nelson` project, divided into 21 logical development phases (Phases 0-20).

---

## Phase 0: Repository and Environment Setup
* **Goal:** Initialize development space and confirm basic compiler settings.
* **Scope:** Local directory creation, Git tracking, Flutter starter code verify.
* **Deliverables:** A clean repository building on Android.
* **Dependencies:** None.
* **Acceptance Criteria:** Build command completes with zero errors.
* **Risks:** Local Flutter version mismatches.
* **Testing Requirements:** Running `flutter doctor -v` and checking device connection.
* **Documentation Requirements:** Update basic installation checklist.
* **Commit Checkpoint:** `feat: initialize flutter application repository`
* **Status:** **Completed**

## Phase 1: Documentation and Architecture Blueprint
* **Goal:** Align technical planning, requirements, and design boundaries before writing code.
* **Scope:** Documenting architecture, security, database models, error specifications.
* **Deliverables:** Full `docs/` folder structure containing all plan markdown files.
* **Dependencies:** Phase 0.
* **Acceptance Criteria:** Markdown links verified; static analysis and test suite verify clean.
* **Risks:** Oversimplification of financial rules.
* **Testing Requirements:** Verify markdown formatting.
* **Documentation Requirements:** Generate this planning suite.
* **Commit Checkpoint:** `docs: add project blueprint roadmap and planning system`
* **Status:** **Completed**

## Phase 2: Flutter Foundation
* **Goal:** Install foundational packages and configure basic environment defines.
* **Scope:** Set up pubspec.yaml with Riverpod, GoRouter, Dio, and configure basic lint configurations.
* **Deliverables:** Updated `pubspec.yaml` and initialized app config classes.
* **Dependencies:** Phase 1.
* **Acceptance Criteria:** Running `flutter pub get` and `flutter analyze` passes.
* **Risks:** Dependency version conflicts.
* **Testing Requirements:** Verify dependencies resolve correctly.
* **Documentation Requirements:** Document selected package versions in ADR registry.
* **Commit Checkpoint:** `chore: configure flutter foundations, dependencies, and environment`
* **Status:** **Completed** (Current Phase)

## Phase 3: Design System and Navigation
* **Goal:** Build the visual theme guidelines and route directories.
* **Scope:** Color palettes, custom typography, shared buttons, and GoRouter configurations.
* **Deliverables:** Navigation route map, shared UI widgets library.
* **Dependencies:** Phase 2.
* **Acceptance Criteria:** Verify route switches without state memory loss.
* **Testing Requirements:** Widget testing of typography and custom buttons.
* **Commit Checkpoint:** `feat: implement go_router navigation and base design system`
* **Status:** **Not Started**

## Phase 4: Authentication and Authorization
* **Goal:** Secure the application entry point.
* **Scope:** Login screen, JWT capture, Secure Storage integration, user logout.
* **Deliverables:** Secure authentication notifier, token interceptors.
* **Dependencies:** Phase 3.
* **Acceptance Criteria:** Unauthorized routes redirect to login screen automatically.
* **Testing Requirements:** Mock authentication service unit and widget tests.
* **Commit Checkpoint:** `feat: integrate secure jwt login flow and token storage`
* **Status:** **Not Started**

## Phase 5: Borrower Management
* **Goal:** Allow Loan Officers to create and view borrower files in the field.
* **Scope:** Borrower registration forms, PII validation rules, local DB cache write.
* **Deliverables:** Borrower forms, borrower list view, local storage tables.
* **Dependencies:** Phase 4.
* **Acceptance Criteria:** Valid forms save to local SQLite; invalid inputs display helper validation warnings.
* **Testing Requirements:** Form input validations unit tests.
* **Commit Checkpoint:** `feat: create borrower onboarding forms and database cache`
* **Status:** **Not Started**

## Phase 6: Loan Product Configuration
* **Goal:** Pull and view pre-configured lending templates from the backend.
* **Scope:** View limits, interest rates, calculation options.
* **Deliverables:** Product detail screens, repository mappings.
* **Dependencies:** Phase 5.
* **Acceptance Criteria:** Display accurate limits and rates matching API returns.
* **Commit Checkpoint:** `feat: integrate loan product configuration viewer`
* **Status:** **Not Started**

## Phase 7: Loan Application Workflow
* **Goal:** Enable submission of loan applications in the field.
* **Scope:** Form capture of loan amount, terms, guarantor PII, and document attachments.
* **Deliverables:** Loan application forms and local drafts storage.
* **Dependencies:** Phase 6.
* **Acceptance Criteria:** Draft applications persist locally and can be uploaded when online.
* **Commit Checkpoint:** `feat: implement loan application form and draft queue`
* **Status:** **Not Started**

## Phase 8: Approval and Disbursement
* **Goal:** Log loan approvals and manage disbursement outcomes.
* **Scope:** Branch manager review layout, disbursement details logging (cash, wallet transfer).
* **Deliverables:** Manager approval dashboard, disbursement receipt logger.
* **Dependencies:** Phase 7.
* **Acceptance Criteria:** Active status applied to loan only upon valid disbursement submission.
* **Commit Checkpoint:** `feat: add manager approval screen and disbursement logger`
* **Status:** **Not Started**

## Phase 9: Repayment Schedules
* **Goal:** Generate and display precise installment timelines.
* **Scope:** Calculator to generate principal and interest breakdown per due date.
* **Deliverables:** Repayment schedule widget and calculation logic.
* **Dependencies:** Phase 8.
* **Acceptance Criteria:** Interest calculations match target formula down to decimal limits (TBC).
* **Testing Requirements:** Comprehensive mathematical unit tests verifying interest allocations.
* **Commit Checkpoint:** `feat: implement repayment schedule generator and viewer`
* **Status:** **Not Started**

## Phase 10: Payments and Receipts
* **Goal:** Enable cashiers to collect loan payments.
* **Scope:** Payment entry form, printing/sharing of receipts (via system share sheets).
* **Deliverables:** Payment entry view, transaction ID generator, PDF receipt export.
* **Dependencies:** Phase 9.
* **Acceptance Criteria:** Every logged payment generates a unique transaction UUID and reduces outstanding balance.
* **Commit Checkpoint:** `feat: add repayment logging and receipt share sheets`
* **Status:** **Not Started**

## Phase 11: Penalties and Collections
* **Goal:** Handle delinquent accounts and log collector actions.
* **Scope:** Late fee formulas, collection activity notes forms.
* **Deliverables:** Late penalty calculator, collection notes view.
* **Dependencies:** Phase 10.
* **Acceptance Criteria:** Late accounts are flagged as Overdue automatically after grace period expiry.
* **Commit Checkpoint:** `feat: add late fee calculations and collection logs`
* **Status:** **Not Started**

## Phase 12: Documents and Notifications
* **Goal:** Handle file storage and SMS updates.
* **Scope:** File attachments (images/PDFs), local file encryption, SMS webhook triggers.
* **Deliverables:** Document manager UI, webhook notification dispatch.
* **Dependencies:** Phase 11.
* **Acceptance Criteria:** Files are compressed and verified before upload; notifications trigger on schedule actions.
* **Commit Checkpoint:** `feat: implement document manager and status notifications`
* **Status:** **Not Started**

## Phase 13: Offline Storage and Synchronization
* **Goal:** Ensure stable offline operations.
* **Scope:** Sync queue tables, network change listeners, retry backoff algorithms, idempotency key injections.
* **Deliverables:** Synchronization worker, conflict UI resolver.
* **Dependencies:** Phase 12.
* **Acceptance Criteria:** Pending offline payments sync sequentially when network is restored.
* **Testing Requirements:** Simulated network dropout integration tests.
* **Commit Checkpoint:** `feat: integrate offline database cache and sync worker`
* **Status:** **Not Started**

## Phase 14: Reports and Analytics
* **Goal:** Display portfolio overview to branch officers.
* **Scope:** Cumulative calculations, collection efficiency ratios, active loan totals charts.
* **Deliverables:** Summary cards, dashboard analytics view.
* **Dependencies:** Phase 13.
* **Acceptance Criteria:** Summary amounts match local database aggregates.
* **Commit Checkpoint:** `feat: develop local analytics and reporting charts`
* **Status:** **Not Started**

## Phase 15: Web Admin Panel
* **Goal:** Launch the desktop Web dashboard.
* **Scope:** System configuration UI, user roles manager, full branch logs.
* **Deliverables:** Web client build, web-specific layout components.
* **Dependencies:** Phase 14.
* **Acceptance Criteria:** Admin settings successfully update database variables.
* **Commit Checkpoint:** `feat: initialize web admin dashboard configuration`
* **Status:** **Not Started**

## Phase 16: n8n Workflows and Integrations
* **Goal:** Automate backend operations using n8n workflows.
* **Scope:** Webhook triggers mapping for SMS notification dispatch and data exports.
* **Deliverables:** Exported n8n workflow JSON blueprints.
* **Dependencies:** Phase 15.
* **Acceptance Criteria:** Triggers execute target actions on n8n platform.
* **Commit Checkpoint:** `feat: orchestrate backend actions via n8n workflows`
* **Status:** **Not Started**

## Phase 17: Security Hardening
* **Goal:** Audit and fix client security vulnerabilities.
* **Scope:** SQLCipher setup, root detection validation, code obfuscation, SSL Pinning.
* **Deliverables:** Security-audited production configuration.
* **Dependencies:** Phase 16.
* **Acceptance Criteria:** Static code analyzer passes with zero security warnings.
* **Commit Checkpoint:** `security: enforce database encryption and secure ssl pinning`
* **Status:** **Not Started**

## Phase 18: Testing and Quality Assurance
* **Goal:** Finalize test coverage.
* **Scope:** Golden test setup, end-to-end user flows regression runs.
* **Deliverables:** High-coverage automated test suites reports.
* **Dependencies:** Phase 17.
* **Acceptance Criteria:** Code coverage reaches minimum of 80% on core use cases.
* **Commit Checkpoint:** `test: execute comprehensive regression and golden UI tests`
* **Status:** **Not Started**

## Phase 19: Release Preparation
* **Goal:** Build signed release binaries.
* **Scope:** Keystore generation, version code increments, App Bundle building.
* **Deliverables:** Signed `.aab` file ready for submission.
* **Dependencies:** Phase 18.
* **Acceptance Criteria:** Release build compiles successfully without debug flags.
* **Commit Checkpoint:** `build: prepare signed release binaries and play store metadata`
* **Status:** **Not Started**

## Phase 20: Production Deployment and Maintenance
* **Goal:** Launch app to production.
* **Scope:** Play Store submission, monitoring dashboard activation, backup schedules verify.
* **Deliverables:** Live production application.
* **Dependencies:** Phase 19.
* **Acceptance Criteria:** App is available on the Play Store; monitoring receives crash logs.
* **Commit Checkpoint:** `chore: release to production and initiate server backups`
* **Status:** **Not Started**
