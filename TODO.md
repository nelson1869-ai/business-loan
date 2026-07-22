# Lending Nelson Current TODO

Completed history belongs in [Development Log](docs/history/DEVELOPMENT_LOG.md). The full remaining plan is in [Delivery Milestones](docs/roadmap/MILESTONES.md).

## Current priority: complete Flutter projection workflows

The backend already provides receipt, statement, dashboard, financial-report, workflow, pagination, and offline-sync APIs. The next focused step is to complete and verify their Flutter presentation.

- [ ] Verify receipt detail uses `GET /api/v1/payments/{paymentId}/receipt` without recalculating totals.
- [ ] Verify loan statement uses `GET /api/v1/loans/{loanId}/statement` and displays reversal history and reconciliation.
- [ ] Verify dashboard cards use `GET /api/v1/dashboard` as their financial source of truth.
- [ ] Add or verify financial-report UI using `GET /api/v1/reports/financial`.
- [ ] Expose appropriate loan workflow actions without permitting invalid transitions.
- [ ] Add widget tests for loading, success, empty, validation, conflict, and offline states.
- [ ] Run `flutter analyze`, `flutter test`, backend checks, and the complete Postman collection.

## Known workflow issue

- [ ] Resolve the successful `complete` transition design. Full payoff currently changes a loan directly to `Paid`, while `complete` requires an Active or Overdue zero-balance loan.

Do not add production-hardening work here unless it becomes an explicit project priority.
