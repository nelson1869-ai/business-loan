# Delivery Milestones

Status reflects the current repository. A checked item is implemented and verified; unchecked items remain product or engineering work.

## Phase 0: Business rules

- [x] Use exact Decimal arithmetic for money and rates.
- [x] Use outstanding principal as the reducing-balance basis.
- [x] Allocate payment to interest, then principal, then unapplied credit.
- [x] Preserve original payments and correct through reversals.
- [ ] Approve supported currencies and rounding boundaries.
- [ ] Approve rate ranges, penalty rules, grace periods, and disclosures.
- [ ] Complete jurisdiction-specific legal and compliance review.

## Phase 1: Loan accounts and schedules

- [x] Persist borrowers, loans, installments, and audit records.
- [x] Support multiple independent loans per borrower.
- [x] Generate and persist installment schedules.
- [x] Provide active and draft creation with request-ID idempotency.
- [x] Provide stable list filtering and pagination.
- [x] Support approve, disburse, activate, default, cancel, and close transitions.
- [ ] Resolve the natural successful `complete` transition after payoff changes status directly to `Paid`.
- [ ] Add formal schedule rescheduling and its audit trail.

## Phase 2: Payments and corrections

- [x] Preview backend allocation before confirmation.
- [x] Support full, partial, early, interest-only, and excess payments.
- [x] Make payment creation idempotent.
- [x] Preserve immutable allocations and ledger history.
- [x] Reverse the latest eligible payment idempotently.
- [x] Reconstruct balances and statuses after reversal.
- [ ] Define product behavior for applying or refunding unapplied credit.
- [ ] Add older-payment reconstruction if non-latest reversal becomes a requirement.

## Phase 3: Projections and reporting

- [x] Generate receipt projections with allocation details.
- [x] Generate reconciled loan-statement projections.
- [x] Generate dashboard portfolio and collection metrics.
- [x] Generate financial reports for collections, interest, risk, aging, and collectors.
- [ ] Add downloadable receipt and statement formats.
- [ ] Add downloadable portfolio reports.

## Phase 4: Offline synchronization

- [x] Use transaction UUID, endpoint, method, payload, and creation time.
- [x] Synchronize borrower creation.
- [x] Synchronize loan creation.
- [x] Synchronize payment creation.
- [x] Synchronize payment reversal.
- [x] Preserve prior successes when a later queue item fails.
- [x] Use financial request IDs to prevent duplicate entries.
- [ ] Add complete user-facing conflict-resolution and retry management.

## Phase 5: Client completeness

- [x] Display backend-generated loan schedules and payment allocations.
- [x] Provide All, Active, Overdue, and Paid portfolio filters.
- [x] Provide development seed/reset access through Settings tooling.
- [ ] Complete and verify all receipt, statement, dashboard, report, and workflow screens against projections.
- [ ] Add accessibility and localization review.
- [ ] Ensure development-only controls are excluded or protected in release builds.

## Phase 6: Verification

- [x] Backend compilation passes.
- [x] Backend tests pass: 63 executed, 60 passed, 3 skipped.
- [x] Alembic reports no pending upgrade operations.
- [x] Postman passes 68 requests and 124 assertions with zero failures.
- [ ] Add continuous integration only when it becomes an explicit project priority.

## Phase 7: Release readiness

- [ ] Add role-based authorization for sensitive actions.
- [ ] Replace all development accounts and secrets.
- [ ] Complete backup and restore testing.
- [ ] Complete privacy, security, and legal review.
- [ ] Define production deployment, monitoring, retention, and incident response.

## Definition of done

- Business behavior is documented and marked implemented or proposed.
- Financial logic remains centralized in backend services.
- Schema changes have reviewed Alembic migrations.
- Success, validation, conflict, idempotency, and reconciliation tests pass.
- Flutter analysis and tests pass for client changes.
- Backend and Postman suites pass for API changes.
- Documentation and OpenAPI remain consistent with implementation.
