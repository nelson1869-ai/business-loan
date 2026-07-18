# App Store Release Plan - Lending Nelson

This plan details release stages, build compilation, and publishing requirements for the `lending-nelson` Android application.

---

## 🚀 Release Lifecycle Stages

```
   ┌────────────────┐      ┌────────────────┐      ┌────────────────┐
   │ 1. Internal    │ ───> │ 2. Alpha       │ ───> │ 3. Beta        │
   │ (QA & Devs)    │      │ (Branch Staff) │      │ (Selected Reps)│
   └────────────────┘      └────────────────┘      └────────────────┘
                                                              │
   ┌────────────────┐      ┌────────────────┐                 │
   │ 5. Production  │ <─── │ 4. Release     │ <───────────────┘
   │ (Google Play)  │      │ Candidate (RC) │
   └────────────────┘      └────────────────┘
```

### 1. Internal Testing
- Distributed to developers and QA engineers via Firebase App Distribution. Used for daily functional checks.

### 2. Alpha (Closed Group)
- Distributed to a small group of branch staff. Used to verify field usability and data entry flows.

### 3. Beta (Open Group)
- Released to selected collection agents. Used to test offline caching under realistic field conditions.

### 4. Release Candidate (RC)
- Final build undergoes automated security regression tests.

### 5. Production
- Published to the Google Play Store console for general staff access.

---

## 📦 Build & Signing Specifications

### Versioning Rules
- Follows [Semantic Versioning](https://semver.org/).
- Incremented in `pubspec.yaml` prior to release:
  ```yaml
  version: 1.0.1+2 # VersionName + VersionCode
  ```

### Release Artifacts
- **App Bundle (`.aab`):** Generated for Play Store submissions to enable dynamic size optimization:
  ```powershell
  flutter build appbundle --release
  ```
- **Release APK (`.apk`):** Compiled for manual testing distributions.

### Keystore Configuration & Signing
- The production keystore certificate (`upload-keystore.jks`) is managed in secure CI environments (e.g., GitHub Actions Secrets) and injected during compilation.
- **Never commit keystore files or raw passwords to Git.**

---

## 🔒 Play Store Compliance Requirements

- **Privacy Policy:** Include a link to the privacy policy document detailing how borrower PII is collected, processed, and secured.
- **Data Safety Declaration:** Declare all data collected by the app (PII, Financial Transactions, Photos/Documents) to ensure transparency on Google Play.
- **Rollback Checklist:** If a critical issue occurs in production, immediately roll back to the last stable release version code on Google Play.
