# User Roles & Permissions - Lending Nelson

This document defines the roles, permissions, and operational limits for all system users.

---

## 🔐 Staff Roles Configuration Matrix

| Role | Onboard Borrower | Submit Application | Approve Application | Record Payment | View Audit Logs | Change Global Config |
| --- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Super Admin** | Yes | Yes | Yes | Yes | Yes | Yes |
| **Business Owner** | Yes | Yes | Yes | Yes | Yes | Yes |
| **Branch Manager** | Yes | Yes | Yes | Yes | Yes | No |
| **Loan Officer** | Yes | Yes | No | No | No | No |
| **Cashier** | Yes | No | No | Yes | No | No |
| **Collector** | Yes | No | No | Yes | No | No |
| **Auditor** | No | No | No | No | Yes | No |
| **Read-Only Staff** | No | No | No | No | No | No |

---

## 📝 Detailed Role Definitions

### 1. Super Admin / Business Owner
* **Description:** System administrator with full read/write privileges.
* **Permissions:** Access to all records, audit logs, system configurations, user profiles, and branch management.
* **Restrictions:** None.

### 2. Branch Manager
* **Description:** Manages branch operations.
* **Permissions:** Approve or reject loan applications, view branch performance reports, edit local staff assignments.
* **Restrictions:** Cannot modify global settings, interest calculations, or system configurations.

### 3. Loan Officer
* **Description:** Field agent onboarding clients and processing applications.
* **Permissions:** Register borrowers, upload onboarding documents, submit loan applications.
* **Restrictions:** Cannot approve loans, log disbursements, or record payments.

### 4. Cashier / Collector
* **Description:** Handles cash collections and overdue accounts follow-ups.
* **Permissions:** View borrower repayment status, log payments, print receipts, and log collection notes.
* **Restrictions:** Cannot edit borrower information, submit loan applications, or approve loans.

### 5. Auditor
* **Description:** Internal inspector checking for fraud and compliance.
* **Permissions:** Read-only access to all transactions, repayment schedules, audit trails, and borrower records.
* **Restrictions:** Cannot modify any system records or configurations.

### 6. Read-Only Staff
* **Description:** General office staff requiring access to records.
* **Permissions:** Read-only access to borrower lists and active loan summaries.
* **Restrictions:** Cannot modify records.

### 7. Borrower (Planned Future Scope)
* **Description:** Customers accessing their own loan status.
* **Permissions:** View active loans, repayment schedules, and payment histories.
* **Restrictions:** Strictly limited to their own records.
