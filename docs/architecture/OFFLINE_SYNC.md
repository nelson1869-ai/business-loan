# Offline-first synchronization

## Availability boundary

Valid local lending actions do not wait for the API. Borrower, loan, repayment,
collection, guarantor, emergency-contact, note, and document-metadata writes use
SQLite as the immediate source of truth and add an encrypted mutation to
`offline_sync_queue` in the same local transaction.

Authentication, server reports, remote notifications, and data that has never
been cached require the server. An expired session may also require the server
before synchronization can resume; queued local data remains durable.

## Local write flow

1. Validate business rules locally.
2. Preserve or create the entity UUID and request/idempotency UUID.
3. Commit the local entity and encrypted outbox mutation together.
4. Update the UI from SQLite.
5. Attempt synchronization in the background or through **Sync Now**.

Financial events are append-only queue items. Loan creation, schedules,
repayments, collections, and payment reversals are never coalesced. Only
explicitly allowlisted profile-style updates may replace the encrypted payload
of an existing pending update while preserving its transaction UUID.

## Queue lifecycle

`pending` -> `syncing` -> one of:

- removed after server confirmation;
- `retryableFailed` with exponential backoff;
- `permanentlyFailed` for invalid terminal requests;
- `conflict` for idempotency conflicts;
- `blockedByDependency` when a dependency cycle is detected;
- `cancelled` after a dependency-safe user cancellation.

A SQLite transaction acquires a drain lease before network submission. Stale
leases are recovered after restart. Missing, duplicated, contradictory,
malformed, or unknown backend result identifiers cause submitted items to
return to a retryable protocol-failure state; they are never left syncing.

## Ordering and exactly-once behavior

The dependency resolver uses deterministic topological ordering, with borrower
before loan and loan before repayment. Cycles are retained and marked for
review. The API validates transaction UUIDs and its strict endpoint/method
allowlist. Each item is independently committed with a durable
`sync_receipts` row in the same PostgreSQL transaction. A retry after a lost
response finds that receipt and does not repeat the mutation.

## Recovery and troubleshooting

- Use **Sync Now** to bypass a scheduled retry delay after connectivity returns.
- Retryable failures remain durable across application restarts.
- Review terminal failures and conflicts before cancellation.
- Parent mutations cannot be deleted or cancelled while active children depend
  on them.
- Never clear the SQLite database to repair synchronization.
- Do not inspect encrypted payload contents in logs or diagnostics.

## Manual server-off test

1. Start the API and authenticate.
2. Stop the API process completely.
3. Create a borrower, create its loan, and record a repayment.
4. Close and reopen the application.
5. Confirm all three records remain visible locally.
6. Restart the API and select **Sync Now**.
7. Confirm the queue clears and PostgreSQL contains exactly one borrower, loan,
   payment, and corresponding receipt per transaction UUID.
