# Accounting Rules

The backend implements a minimal double-entry ledger under
`backend/app/features/accounting`. Money uses `Decimal` and PostgreSQL
`NUMERIC(18,2)`. Every posted entry requires an open period, one currency, at
least two one-sided lines, and equal debit and credit totals. PostgreSQL defers
the balance check to the transaction boundary so an incomplete or unbalanced
entry cannot commit.

Posted journal entries and lines cannot be updated or deleted. Corrections use
new compensating entries. Idempotency and source-reference constraints prevent
duplicate posting, and every service posting emits an audit event.

Current posting integrations cover loan disbursement, allocated repayments,
unapplied credit, payment reversal, write-off, post-write-off recovery, and cash
deposit. The daily trial-balance endpoint is read-only.

Chart-of-account mappings, recognition timing, write-off treatment, tax, and
report presentation still require approval from the business's qualified
accounting adviser. The seeded PHP accounts are operational defaults, not
accounting advice.
