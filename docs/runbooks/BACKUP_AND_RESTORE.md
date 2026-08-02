# PostgreSQL Backup and Restore

## Status and ownership

This repository does **not** prove that scheduled backups are deployed. The production owner must configure, monitor, and periodically restore-test backups. Assign a named backup operator and a different restore reviewer.

Business owners must approve the recovery point objective (RPO), recovery time objective (RTO), retention period, and storage jurisdictions. Suggested planning targets—not commitments—are a daily encrypted logical backup, continuous WAL archiving where supported, and quarterly restore exercises.

## Backup requirements

- Use `pg_dump` custom format from a trusted host over an encrypted connection.
- Encrypt before transfer to off-device storage using an organization-controlled key.
- Keep at least one copy outside the database host and outside its normal administrator account.
- Record database name, PostgreSQL version, Alembic revision, UTC timestamp, checksum, encryption-key identifier, operator, and result.
- Never place database passwords in command history, scripts, filenames, logs, or Git. Use a protected password file or secret manager.

Example (adapt paths and secret handling):

```powershell
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
pg_dump --format=custom --no-owner --no-acl --file "lending_nelson_$stamp.dump" lending_nelson
Get-FileHash "lending_nelson_$stamp.dump" -Algorithm SHA256
```

Encrypt the dump with the approved enterprise encryption tool, verify the encrypted file can be decrypted by the recovery role, transfer it off-device, then securely remove the unencrypted temporary file according to the host policy.

## Restore procedure

1. Declare the restore target and incident/change ticket. Never overwrite production during a test.
2. Provision an isolated PostgreSQL instance with a compatible major version.
3. Retrieve and checksum the encrypted backup; compare it with the recorded manifest.
4. Decrypt only into protected temporary storage.
5. Create an empty database and restore:

```powershell
createdb lending_nelson_restore_test
pg_restore --exit-on-error --clean --if-exists --no-owner --no-acl --dbname lending_nelson_restore_test <dump-file>
```

6. Configure a temporary backend to the restored database with `APP_ENV=staging`; never enable the fixed OTP.
7. Run `alembic current`, `alembic upgrade head`, `alembic check`, readiness checks, and agreed financial reconciliation queries.
8. Verify row counts, latest loan/payment/audit timestamps, payment-allocation totals, borrower-account access boundaries, and n8n outbox state.
9. Record elapsed time, recovered-through timestamp, errors, reviewer sign-off, and securely remove temporary plaintext.

## Point-in-time recovery

PITR requires PostgreSQL base backups plus continuous WAL archiving; `pg_dump` alone cannot provide it. Configure repository/retention/encryption in the deployment platform, test recovery to a timestamp, and document the resulting demonstrated RPO/RTO before claiming PITR capability.
