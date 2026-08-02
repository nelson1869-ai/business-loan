# Compromised Account Response

1. Disable the account and revoke active refresh tokens/devices immediately through an authorized administrator.
2. Preserve authentication, rate-limit, audit, sync, payment, policy, approval, and outbox records.
3. Determine scope by actor ID and time window. Avoid exporting full borrower PII.
4. Rotate the user's password and any exposed API, n8n, Firebase, database, signing, or webhook credentials. Rotate shared credentials for all consumers.
5. Review sensitive actions: user/role changes, borrower edits, loan lifecycle transitions, payments/reversals, policy decisions, reconciliation, exports, and manual accounting.
6. Reject pending approvals created by the compromised maker until independently reviewed.
7. Correct financial effects only with approved reversal/adjusting entries and explicit incident references.
8. Restore access with fresh credentials and least privilege after checker approval.
9. Record detection, containment, scope, rotations, financial review, notifications required by applicable policy/law, and closure.

Do not include tokens, passwords, OTPs, national IDs, or complete borrower records in the incident ticket.
