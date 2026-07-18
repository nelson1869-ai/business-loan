# Risk Register - Lending Nelson

This document identifies, analyzes, and proposes mitigation strategies for the primary technical and business risks associated with the project.

---

## ⚡ Risk Analysis Matrix

| Risk | Description | Probability | Impact | Severity | Mitigation Strategy | Owner | Status |
| --- | --- | :---: | :---: | :---: | --- | :---: | :---: |
| **Financial Calculation Errors** | Mismatch in interest, penalty, or principal allocations. | Low | Critical | **High** | Write extensive mathematical unit test suites comparing Dart values with raw double ledger sheets. | Lead Architect | Open |
| **Data Privacy Exposure** | Unauthorized access to borrower personal identifiable information (PII). | Medium | High | **High** | Encrypt PII fields in local database; enforce TLS 1.3 transport security. | Lead Developer | Open |
| **Weak Authentication** | Session hijacking or credentials theft. | Low | High | **High** | Store tokens only in hardware-backed Secure Storage; enforce session expiry. | Lead Developer | Open |
| **Incorrect Payment Allocation** | Payments allocated to wrong installment categories. | Medium | High | **High** | Enforce a strict allocation sequence: Fees ➔ Penalties ➔ Interest ➔ Principal. | Core Backend | Open |
| **Offline Sync Conflicts** | Simultaneous updates in offline and online spaces. | High | Medium | **High** | Enforce server-authoritative ledger updates; use Last-Write-Wins for basic PII details. | Sync Lead | Open |
| **Duplicate Transactions** | Retrying timed-out requests charges the user twice. | Medium | High | **High** | Client must generate a unique UUID for every transaction, sent as an idempotency key header. | Lead Architect | Open |
| **Insecure Local Storage** | Database file extracted from a lost/stolen device. | Medium | High | **High** | Implement SQLCipher file-level database encryption on the mobile client. | Security Lead | Open |
| **Inadequate Audit Logs** | Inability to reconstruct system mutations during disputes. | Low | High | **High** | Build an immutable AuditLog entity logging every status change and the active user ID. | Lead Architect | Open |
| **Dependency Vulnerabilities** | Outdated library packages introduce security bugs. | Medium | Medium | **Medium** | Conduct monthly dependency audits using `flutter pub outdated`. | Dev Team | Open |
| **Backend Down Time** | Client unable to submit details or perform updates. | Medium | Medium | **Medium** | Cache key product parameters locally; build an offline submission draft queue. | Sync Lead | Open |
| **Notification Delivery Failures** | Overdue notifications are not delivered to borrowers. | High | Medium | **Medium** | Build a retry scheduler in n8n; track notification logs in the backend. | Automation Lead | Open |
| **Scope Expansion** | Adding direct integrations before core flows are verified. | High | Medium | **Medium** | Define strict boundaries in Phase Plans; mark advanced integrations as future scope. | Project Manager | Open |
