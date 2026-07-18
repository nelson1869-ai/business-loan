# Product Requirements Document (PRD) - Lending Nelson

This document details the functional, non-functional, security, and release requirements for the `lending-nelson` application.

---

## 📋 1. Product Overview & Goals

`lending-nelson` is a field-oriented mobile application designed to simplify the registration of borrowers, submission of loan applications, and collection of installment payments in the field.

### Strategic Goals
- **Digitize Field Operations:** Replace paper forms with local digital forms.
- **Improve Financial Controls:** Keep a clear log of transactions to prevent incorrect allocations and employee fraud.
- **Support Offline Operations:** Enable field work without continuous internet coverage.

---

## 👥 2. User Personas

### Loan Officer (Field Representative)
* **Goal:** Register borrowers and submit loan applications in the field.
* **Pain Point:** Weak cellular coverage, slow processing, manual paperwork.

### Branch Manager (Approver)
* **Goal:** Review and approve loan applications, monitor portfolio balances.
* **Pain Point:** Lack of clear documentation, delayed processing.

### Cashier / Collector (Transaction Specialist)
* **Goal:** Collect cash payments, issue receipts, and chase late accounts.
* **Pain Point:** Keeping track of manual paper logs.

---

## ⚙️ 3. Functional Requirements

### 1. Borrower Profiles
- Capture full PII: Name, DOB, National ID, Phone, Address, Bank details.
- Attach files (Image/PDF) for identity verification.

### 2. Loan Processing
- View loan product parameters (rates, terms limits).
- Calculate installment payments.
- Submit loan applications for manager approval.

### 3. Repayments & Receipts
- Record cash repayments.
- Generate receipt confirmation with transaction UUID.
- Export receipt PDF for sharing.

---

## 📐 4. Non-Functional Requirements

### 1. Security Requirements
- Password hashes and sensitive data must never be visible in logs.
- Enforce TLS 1.3 for API communication.
- Enforce local database encryption on the mobile client.

### 2. Performance Requirements
- Locally cached screens must load in < 100ms.
- Remote API requests must resolve in < 2 seconds under ordinary network conditions.

### 3. Availability Requirements
- The mobile client must run completely offline for core workflows (Borrower Registration, Payment Collection).
- The system must queue actions for automatic synchronization when network coverage is restored.

### 4. Accessibility Requirements
- All forms must have clear labels and support screen readers.
- Color contrast ratio must conform to WCAG 2.1 AA standards.

### 5. Auditability Requirements
- Save an immutable audit trail entry for every status mutation.
- Audit entries must record the User ID, action description, timestamp, and entity ID.

### 6. Reporting Requirements
- Daily totals dashboard tracking: Total Disbursed, Total Payments Collected, Overdue Balance.

---

## 🚀 5. Release Criteria

A release version is ready for production only when:
- Static analysis passes with no warnings.
- Code test coverage reaches >= 80%.
- Manual smoke tests verify core flows (Login ➔ Onboard Borrower ➔ Log Payment ➔ Sync).
- Release binaries compile without debug flags.
