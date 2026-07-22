# Lending Nelson Product Roadmap

The application already supports core borrower, loan, installment, payment, reversal, projection, reporting, and offline-sync workflows. This roadmap lists remaining work rather than describing implemented features as future plans.

This is software planning, not legal or financial advice. Interest, disclosure, licensing, privacy, collections, tax, retention, and reporting requirements need jurisdiction-specific review before production use.

## Implemented foundation

- Independent loans per borrower
- Exact Decimal schedule and payment calculations
- Draft and active loan creation with request-ID idempotency
- Loan lifecycle actions and persisted timestamps
- Partial, early, interest-only, payoff, and excess-credit allocations
- Immutable payment reversals
- Receipt and loan-statement JSON projections
- Dashboard and financial-report projections
- Stable loan and payment pagination
- Offline borrower, loan, payment, and reversal processing
- Automated backend and Postman regression coverage

## Remaining product work

### Product decisions

- Confirm supported currencies and rounding boundaries.
- Confirm rate ranges, supported periods, and disclosure language.
- Decide grace-period, penalty, fee, and rescheduling policies.
- Define borrower exposure limits and override permissions.
- Decide how unapplied credit may be refunded or applied later.

### Financial capabilities

- Formal interest-accrual ledger if daily persisted accrual is required.
- Formal schedule-rescheduling workflow with before/after audit history.
- Statement and receipt export formats such as PDF or CSV.
- Portfolio report export and configurable report dimensions.
- Explicit reconciliation and repair tooling for operational support.

### Client capabilities

- Full UI coverage for backend statements, receipts, reports, and lifecycle actions.
- Visible offline conflict-resolution and retry management.
- Better accessibility, localization, and currency formatting.
- Clear separation or removal of development-only tools in release builds.

### Release readiness

- Role-based permissions for sensitive actions and reversals.
- Backup and restore exercises.
- Production environment and secret-management design.
- Privacy, security, and jurisdictional review.
- Deployment, monitoring, incident-response, and data-retention plans.

## Related documents

- [Loan and Payment Rules](../domain/LOAN_AND_PAYMENT_RULES.md)
- [Delivery Milestones](MILESTONES.md)
- [System Overview](../architecture/SYSTEM_OVERVIEW.md)
- [Development Log](../history/DEVELOPMENT_LOG.md)

Keep current behavior in architecture and domain documents, remaining work here, and dated completed work in the development log.
