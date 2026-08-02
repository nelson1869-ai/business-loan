# Production Release Checklist

- [ ] All Flutter/backend formatting, analysis, tests, coverage, type, migration, and security gates pass.
- [ ] One Alembic head; clean upgrade, drift check, and tested downgrade/upgrade path.
- [ ] Production `APP_ENV`; fixed OTP disabled; explicit HTTPS API/CORS; strong secrets from a secret manager.
- [ ] No localhost API, debug logging, debug signing, placeholder secret, or development Firebase configuration.
- [ ] Release keystore/signing configuration exists outside Git and is recoverably backed up.
- [ ] Encrypted backup completed and latest restore exercise is within policy.
- [ ] Policy/accounting/reconciliation migrations reviewed by financial and operational owners.
- [ ] Monitoring, log retention/redaction, alerting, n8n recovery, and rollback owners confirmed.
- [ ] RPO/RTO, retention, late-fee, settlement, write-off, variance, and approval thresholds have named approvers.
- [ ] Release evidence and post-deployment financial smoke checks recorded.

## Android flavors and signing

Both mobile projects provide `development`, `staging`, and `production` flavors.
Development and staging append `.dev` and `.staging` to their production package
identifiers, preventing test installations from replacing the production app.

Each app requires an uncommitted `android/key.properties` for release builds:

```properties
storePassword=<secret>
keyPassword=<secret>
keyAlias=upload
storeFile=<absolute-or-android-relative-keystore-path>
```

Blank values, `your_...` placeholders, missing files, and debug release signing are
rejected. Keystores and `key.properties` remain ignored by Git.

Production build commands:

```powershell
flutter build apk --release --flavor production `
  --dart-define=APP_ENV=production `
  --dart-define=API_BASE_URL=https://api.example.com `
  --dart-define=LOCAL_BORROWER_OTP_ENABLED=false `
  --dart-define=DEBUG_LOGGING_ENABLED=false

Set-Location apps\borrower_mobile
flutter build apk --release --flavor production `
  --dart-define=APP_ENV=production `
  --dart-define=API_BASE_URL=https://api.example.com `
  --dart-define=LOCAL_BORROWER_OTP_ENABLED=false `
  --dart-define=DEBUG_LOGGING_ENABLED=false
```

The applications reject production startup when development OTP, debug logging,
localhost, non-HTTPS, or an invalid API URL is configured. CI generates temporary
test-only keystores and builds both production flavors; it never uses a production
signing secret.
