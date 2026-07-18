# Product Blueprint - Lending Nelson

## Product Vision & Goals

`lending-nelson` is a modern, field-focused lending solution designed to simplify, automate, and digitize lending operations. It enables loan officers to manage borrowers, process applications, and record repayments directly from mobile devices, even in environments with intermittent internet connectivity.

### Business Goals
* **Automate Loan Lifecycle:** Reduce processing times from applications to disbursement.
* **Empower Field Staff:** Enable mobile-first borrower registration and payment collection.
* **Improve Repayment Rates:** Automate late reminders and track collection activities.
* **Ensure Auditability:** Maintain logs of every operational state change.

### Target Users
* **Loan Officers:** Register borrowers and submit applications in the field.
* **Branch Managers:** Review and approve/reject applications.
* **Cashiers & Collectors:** Record repayments and follow up on overdue amounts.
* **Super Admins / Business Owners:** Oversee company-wide portfolio performance and settings.

### Core Problems Solved
* **Offline Field Work:** Enabling operations in areas with weak or no mobile signal.
* **Manual Errors:** Preventing incorrect calculations of interest, grace periods, or penalties.
* **Lack of Transparency:** Providing instant receipts and automated transaction logs.

---

## Scope Matrix

### Mobile Application Scope (Primary Target)
* **Borrower Profile Management:** Registration, documentation uploads, contact details.
* **Loan Lifecycle Management:** Submission, disbursement logging, and active status tracking.
* **Collections & Payments:** On-field payment logging with offline receipt queuing.
* **Offline Local Storage:** Full read/write access to synced client records.

### Web Admin Panel Scope (Future Target - Phase 15)
* **Configuration Panel:** Set up loan product rules, global penalties, and company parameters.
* **Staff Access Control:** Manage system roles, permissions, and branch assignments.
* **Advanced Reporting:** Centralized ledger dashboard, branch performance statistics, and audit trail viewing.

---

## Detailed Functional Modules

### 1. Borrower Management
- Fields for basic PII, verified contacts, physical address, and employer data.
- Attach mandatory onboarding documentation (ID copies, income proof).

### 2. Loan Applications
- Selection of pre-configured Loan Products.
- Calculator estimating interest rates, service fees, and installment amounts.

### 3. Loan Approval & Disbursement
- Multi-step verification: Loan Officer submits, Branch Manager approves.
- Logging of disbursement method (Cash, Bank Transfer, Mobile Wallet) with receipt proof.

### 4. Repayment Schedules & Payment Recording
- Automatic generation of schedules (Equal Principal, Equal Installments, Flat Interest, TBC).
- Cashier records repayments. Instant creation of receipt transaction identifiers.

### 5. Late Penalties & Restructuring
- Automated penalty calculations based on grace periods and outstanding balance rules.
- Restructuring capability: Allows extending terms or adjusting schedules for delinquent borrowers.

### 6. Notifications & Documents
- SMS notifications triggered by status changes (approved, disbursed, payment received, penalty applied).
- System document generator for contracts and receipts.

### 7. Audit History
- Immutable system logs recording every action: who performed it, when, and the before/after state.

---

## System Integrations

### n8n Workflow Integration
- **Webhook Triggers:** Trigger workflows on key events (e.g., *Application Submitted*, *Payment Recorded*).
- **Automated Messaging:** Orchestrate third-party SMS or Email services.
- **Reporting Syncs:** Push aggregate daily logs to shared storage.

### Future Integrations
- **Payment Gateways:** Integrate mobile wallets or bank APIs for automated loan disbursements and collection reconciliations.
- **Accounting Systems:** Connect to ledger platforms (e.g., QuickBooks or Xero) to sync financial balances.

---

## Explicit Non-Goals for First Release

* **Self-Service Borrower App:** The first release targets internal staff only; no direct customer-facing app.
* **Automated Credit Scoring:** No automated algorithms for credit evaluation; approvals rely entirely on manual officer assessments.
* **Direct Bank Integrations:** No direct bank transfers via API; all transactions are recorded manually by staff.
