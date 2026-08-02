# Cash Reconciliation Rules

Collection sessions are implemented under `/api/v1/collection-sessions` with
the lifecycle `open -> collecting -> submitted -> reviewed -> reconciled ->
deposited -> closed`. Sessions record collector, opening/expected/actual cash,
variance and reason, reviewer, deposit amount/reference, and lifecycle
timestamps. Cash payments require a collector-owned active session and a unique
receipt number.

The collector cannot review their own session. A non-zero variance requires an
explanation before submission, and an unexplained variance blocks closure.
Reconciliation marks associated payments as reconciled; deposit posts a
balanced cash-to-bank journal. Reconciled payments remain append-only and an
approved compensating reversal is required for correction.

Material-variance thresholds and cash-handover policy remain unresolved
business controls and must be configured only after documented approval.
Location metadata is optional and privacy-sensitive.
