# Database Disaster Recovery

## Trigger conditions

Invoke this runbook for unavailable/corrupt PostgreSQL, destructive operator error, ransomware suspicion, unrecoverable schema deployment, or failed integrity checks.

## Response

1. Stop application writes and offline replay. Preserve database, PostgreSQL, host, and application logs.
2. Identify incident commander, database operator, financial reviewer, and communications owner.
3. Classify failure time and last known-good time. Do not guess the recovery point.
4. Choose failover, PITR, or logical restore based on tested deployment capability—not convenience.
5. Restore using `BACKUP_AND_RESTORE.md` into an isolated instance first.
6. Validate Alembic head, schema drift, table/constraint presence, journal/payment balance checks, request-ID uniqueness, sync receipts, audit continuity, and outbox state.
7. Reconcile transactions between recovery point and write shutdown using device queues, immutable receipts, bank/cash evidence, and audit logs. Replay only through normal idempotent APIs.
8. Rotate database and service credentials if compromise is possible.
9. Resume read traffic, then controlled writes, then sync replay. Monitor conflicts and duplicates.
10. Complete financial sign-off and a blameless post-incident review.

Never repair financial history by deleting payments, reversals, journals, or audit records.
