# Security Blueprint - Lending Nelson

This document outlines the security architecture and compliance safeguards designed for the `lending-nelson` application.

---

## 🔒 Client-Side Security

### 1. Authentication & Session Management
- **Token-Based Auth:** JWT tokens (Access and Refresh) are used. Access tokens have short lifespans (e.g., 15 minutes).
- **Secure Token Storage:** Auth tokens are saved using the [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) package, which utilizes Keychain on iOS and Keystore on Android.
- **Biometric Lock:** Optional PIN or biometric unlock (FaceID/Fingerprint) before displaying sensitive active screens.
- **Automatic Expiration:** User sessions expire after 30 minutes of inactivity, clearing tokens from memory and requiring re-login.

### 2. Encryption at Rest & Database Protection
- **Local DB Encryption:** If local SQLite/Isar is used, database files must be encrypted using SQLCipher, with the decryption key derived dynamically and stored in Secure Storage.
- **Personally Identifiable Information (PII):** Borrower names, phone numbers, and National IDs must be encrypted prior to writing to local tables.

### 3. Device Integrity & Root Detection
- **Root/Jailbreak Detection:** Check device integrity on launch. The app will trigger warnings or restrict offline cache storage if run on rooted Android devices.
- **Screenshot Protection:** Restrict screenshot capabilities on sensitive loan screens by setting `FLAG_SECURE` in Android MainActivity.

---

## 🌐 Network & API Security

### 1. Encryption in Transit
- **TLS 1.3 Enforcement:** All communication between the mobile client and the backend must happen over HTTPS (TLS 1.3).
- **SSL Pinning:** Use Dio with SSL pinning to prevent Man-in-the-Middle (MITM) attacks by packaging server certificates directly in the asset bundle.

### 2. Input Validation & Request Control
- **Strict Client-Side Validation:** All fields (e.g., currency amounts, phone numbers) are scrubbed and validated against regex patterns before API dispatch.
- **Idempotency Keys:** Every mutation includes a unique client-generated UUID in the headers (`X-Idempotency-Key`) to prevent duplicate transactions.

---

## 📝 Logging & Audit Guidelines

- **Redaction of Sensitive Data:** Loggers must intercept and sanitize output. Under no circumstances should passwords, JWT tokens, credit card details, or full National ID strings be printed to debug consoles or external log aggregate tools.
- **Immutable Audit Trail:** Write entries locally to `AuditLog` for changes (e.g., payment receipt, loan application creation). These entries must sync to the server's immutable log database.

---

## 📦 Secrets Management & OWASP Compliance

- **No Secrets in Git:** Signing keystore keys, Firebase client secrets, and third-party API configurations are never committed. They are loaded at build time using Dart environment defines:
  ```powershell
  flutter build apk --dart-define=API_URL=https://api.lendingnelson.com
  ```
- **OWASP Mobile Top 10 Alignment:**
  - *M1: Improper Credential Usage* ➔ Handled via Keystore/Secure Storage.
  - *M2: Inadequate Supply Chain Security* ➔ Monthly automated dependency vulnerability scanning using `flutter pub outdated`.
  - *M4: Insufficient Input/Output Validation* ➔ Sanitized input models.
  - *M8: Security Decisions via Untrusted Inputs* ➔ Strict server-side role and permission validation for all API actions.
