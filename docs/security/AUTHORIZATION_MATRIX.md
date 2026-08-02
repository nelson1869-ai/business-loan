# Authorization Matrix

The backend permission catalog and default role grants are defined centrally in
`backend/app/core/authorization.py`. Tokens continue carrying the role name; the
database user is reloaded on every authenticated request, so a changed role takes
effect without trusting a stale token claim.

| Role | Operational scope |
|---|---|
| Owner / legacy admin | Every declared permission |
| Manager | All declared permissions except user management |
| Legacy officer | Borrower and loan creation, payment collection, receipt reprint, reconciliation submission, report view |
| Loan officer | Borrower and loan creation, payment collection, receipt reprint, report view |
| Collector | Payment collection, receipt reprint, reconciliation submission |
| Cashier | Payment collection, reconciliation approval, accounting and report view |
| Auditor | Accounting, audit, and report read/export only |
| Read-only support | Report view only |

Implemented permission checks cover loan creation and workflow commands, payment
collection/reversal, policy administration, accounting views, collection-session
submission/approval, and user management. Existing borrower-token audience checks
remain separate.

Loan approval records the checker in `approved_by_user_id`; a loan's creator cannot
approve that loan. Policy activation and reconciliation review also prohibit self
approval and record checker identity and timestamp.

The generic approval queue records action, entity, maker, checker, request and
decision reasons, safe before/after snapshots when supplied by trusted services,
and timestamps. Decisions lock the request row and are final. Payment reversals
must reference an approved request bound to that exact payment; only its maker can
execute it, and execution consumes the approval once.

Restructuring, write-off, rate modification, large-variance thresholds, and manual
accounting adjustments still need their business commands connected to this queue.
They must not be described as fully maker-checker controlled until those commands
exist and are tested.

Role grants are operational defaults, not legal policy. Deployment owners must
review them against staffing, segregation-of-duty, and local regulatory needs.
