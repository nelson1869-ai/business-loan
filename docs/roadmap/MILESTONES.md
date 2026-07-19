# Personal Lending Delivery Milestones

Build the financial ledger in small phases so calculations can be tested before
more features depend on them.

## Phase 0: Confirm version-one business rules

- [ ] Confirm fixed scheduled rates and daily off-schedule proration with examples.
- [ ] Confirm outstanding principal as the interest basis.
- [ ] Confirm interest-first payment allocation.
- [ ] Define allowed lender-selected rate ranges and supported rate periods.
- [ ] Define rounding and currency rules.
- [ ] Define multiple-active-loan and exposure rules.
- [ ] Confirm supported terms, frequencies, and equal-payment calculation.
- [ ] Review applicable lending, privacy, tax, and collection requirements.

Deliverable: approved examples with hand-calculated expected results.

## Phase 1: Loan accounts

- [ ] Add loan, loan status, and loan event models.
- [ ] Create PostgreSQL and SQLite migrations.
- [ ] Add loan creation and listing APIs.
- [ ] Add rate entry, calculation preview, and confirmation to loan creation.
- [ ] Show all loans grouped by borrower.
- [ ] Show total borrower exposure before a new loan.
- [ ] Require confirmation for a second active loan.

Deliverable: one borrower can hold several independent active loans.

## Phase 2: Interest engine

- [ ] Implement a pure decimal interest-calculation service.
- [ ] Support mid-cycle date calculations.
- [ ] Keep accrued interest separate from principal.
- [ ] Add boundary tests for February, leap years, and 31-day cycles.
- [ ] Add examples from `LOAN_RULES.md` as automated tests.
- [ ] Verify a 600 payment on 1,100 due leaves 500 principal and 50 next interest.

Deliverable: calculations match approved hand-worked examples exactly.

## Phase 3: Flexible payments

- [ ] Add payment and payment-allocation models.
- [ ] Preview allocation before confirmation.
- [ ] Support interest-only payments.
- [ ] Support partial payments.
- [ ] Support early principal reduction.
- [ ] Stop future interest when an early payment fully settles principal.
- [ ] Continue remaining-cycle interest after interest-only or partial payment.
- [ ] Support explicit credit or refund for overpayment.

Deliverable: every payment produces balanced, understandable allocations.

## Phase 4: Schedules and arrears

- [ ] Generate expected payment-cycle entries.
- [ ] Support borrower-requested terms approved by the lender.
- [ ] Generate 10 installments for a 5-month twice-monthly schedule.
- [ ] Calculate regular installments with a final-payment adjustment.
- [ ] Recalculate only the final installment to produce a zero balance.
- [ ] Store exact due dates and installment statuses.
- [ ] Count calendar days between due date and effective payment date.
- [ ] Show days overdue and grace-period status separately.
- [ ] Accrue ordinary interest through a late payment date.
- [ ] Keep the regular due day unless a formal reschedule is recorded.
- [ ] Track unpaid and partially paid interest.
- [ ] Mark overdue schedules without changing historical amounts.
- [ ] Add borrower and portfolio arrears views.
- [ ] Add configurable reminders without automatic collection actions.

Deliverable: the lender can distinguish principal, current interest, and arrears.

## Phase 5: Corrections, receipts, and audit

- [ ] Add payment reversal instead of destructive deletion.
- [ ] Generate receipts with allocation details.
- [ ] Record actor, timestamps, device, and reason for overrides.
- [ ] Redact borrower PII from operational logs.
- [ ] Add statement export for one loan and all borrower loans.

Deliverable: every balance can be reconstructed from immutable events.

## Phase 6: Offline synchronization

- [ ] Assign stable UUIDs on the device.
- [ ] Make payment creation idempotent.
- [ ] Detect version conflicts before overwriting financial records.
- [ ] Require user resolution for conflicting payment changes.
- [ ] Test interrupted and repeated synchronization.

Deliverable: reconnecting never duplicates a loan, accrual, or payment.

## Phase 7: Security and release readiness

- [ ] Add role-based permissions for payment overrides and reversals.
- [ ] Replace development credentials and secrets.
- [ ] Complete backup and restore testing.
- [ ] Add backend API tests and end-to-end financial scenarios.
- [ ] Complete security, privacy, and jurisdictional review.
- [ ] Create a production deployment and monitoring plan.

Deliverable: documented approval for controlled production use.

## Definition of done for every phase

- Business rules are documented.
- Database migrations are reversible and reviewed.
- Calculation and failure-path tests pass.
- Flutter analysis and tests pass.
- API validation and authorization are tested.
- Student documentation and progress tracker are updated.
