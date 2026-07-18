# Project Milestones - Lending Nelson

This document outlines the key milestones (M0-M9) used to track release readiness.

---

## Milestone 0: Project Initialized (Current)
* **Target Outcome:** Base repository configured and verified.
* **Required Phases:** Phase 0.
* **Exit Criteria:** Flutter starter project builds on Android; Git remote is connected.
* **Required Tests:** Basic smoke test.
* **Required Documentation:** Root README.md update.
* **Demo Requirements:** None.

## Milestone 1: Architecture Foundation Complete
* **Target Outcome:** Technical blueprints approved; foundational libraries configured.
* **Required Phases:** Phase 1, Phase 2, Phase 3.
* **Exit Criteria:** Dependencies installed; router and state providers scaffolded.
* **Required Tests:** Empty test run; routing tests.
* **Required Documentation:** ADR decisions registry updated.
* **Demo Requirements:** Run blank app showing navigation between placeholder pages.

## Milestone 2: Authentication Complete
* **Target Outcome:** Secure user session management.
* **Required Phases:** Phase 4.
* **Exit Criteria:** Session tokens stored securely; unauthenticated route requests redirect.
* **Required Tests:** Unit tests for secure storage mock; token injection tests.
* **Required Documentation:** Security document update.
* **Demo Requirements:** Show successful login and automatic session timeout.

## Milestone 3: Borrower Onboarding Complete
* **Target Outcome:** Field entry of customer data.
* **Required Phases:** Phase 5.
* **Exit Criteria:** Borrower entry form saves directly to local cache.
* **Required Tests:** Form input validation rules tests.
* **Required Documentation:** Borrower module guide.
* **Demo Requirements:** Onboard a new borrower with offline details.

## Milestone 4: Loan Workflow Complete
* **Target Outcome:** Active contracts creation from application.
* **Required Phases:** Phase 6, Phase 7, Phase 8.
* **Exit Criteria:** Loan application submitted, reviewed by manager, and disbursed.
* **Required Tests:** Status transition checks.
* **Demo Requirements:** Move a loan application from draft status to active status.

## Milestone 5: Payment Workflow Complete
* **Target Outcome:** Financial payments collection.
* **Required Phases:** Phase 9, Phase 10.
* **Exit Criteria:** Payment collections generated with receipt outputs.
* **Required Tests:** Financial allocation logic unit tests.
* **Required Documentation:** Payment workflow instructions.
* **Demo Requirements:** Log payment and export receipt PDF.

## Milestone 6: Offline-Ready Beta
* **Target Outcome:** Stable operation without network.
* **Required Phases:** Phase 11, Phase 12, Phase 13.
* **Exit Criteria:** Queue writes, connections restoration checks, automatic sync execution.
* **Required Tests:** Network latency and packet drop simulations.
* **Demo Requirements:** Log multiple payments offline, restore network, and show sync.

## Milestone 7: Admin Panel Beta
* **Target Outcome:** Centralized web console.
* **Required Phases:** Phase 14, Phase 15, Phase 16.
* **Exit Criteria:** Web configuration saves; audit logs visible in browser.
* **Demo Requirements:** Update global interest rate on Web Admin and sync to mobile.

## Milestone 8: Release Candidate (RC)
* **Target Outcome:** Fully audited, feature-complete release build.
* **Required Phases:** Phase 17, Phase 18, Phase 19.
* **Exit Criteria:** Final QA passes; SQLCipher activated; signed app bundle built.
* **Required Tests:** Full regression tests, golden tests (>= 80% coverage).
* **Demo Requirements:** End-to-end user flows demonstration on physical device.

## Milestone 9: Production Release
* **Target Outcome:** Deploy live to users.
* **Required Phases:** Phase 20.
* **Exit Criteria:** App is live on the Play Store; production logging running.
