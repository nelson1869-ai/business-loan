# Lost Device Response

1. Record reporter, user/borrower account, device, last known use, and UTC incident time. Do not record unnecessary PII.
2. Disable the affected staff account or borrower device through an authorized administrator. Revoke all affected refresh tokens; do not wait for access-token expiry when misuse is suspected.
3. Rotate credentials exposed on the device. Never ask the user to send passwords, OTPs, or tokens.
4. Review audit logs, sync receipts, payments, reversals, borrower changes, and device registrations since the last known-safe time.
5. Preserve suspicious records; reverse financial errors through approved compensating transactions, never deletion.
6. For officer offline data, determine whether unsynced mutations existed. Device loss may make unsynced encrypted local data unrecoverable; do not recreate financial events without evidence and approval.
7. Enroll a replacement device, require fresh authentication, and verify minimum supported OS, screen lock, and encryption.
8. Document containment, review findings, recovery actions, and closure approval.

Remote wipe and mobile-device-management capabilities are deployment decisions and are not proven by this repository.
