# Backup & Disaster Recovery - Lending Nelson

This document details the policies for backing up data and restoring operations in the event of hardware failure, corruption, or natural disaster.

---

## 💾 Backup Scope & Schedules

All backup files must be encrypted using AES-256 and stored in a separate, secure cloud storage region.

| Target | Backup Scope | Frequency | Retention Period |
| --- | --- | --- | --- |
| **Production Database** | Full schema & transactions ledger tables | Daily (Automated at 00:00 UTC) | 7 years (Audit compliance) |
| **Uploaded Documents** | Borrower IDs, signed contract PDF files | Weekly | Indefinite |
| **System Settings** | Server configurations, API environment variables | Monthly | 1 year |

---

## ⏱️ Recovery Objectives (RPO & RTO)

### Recovery Point Objective (RPO)
- **Target:** **24 Hours**
- **Definition:** The maximum amount of data loss the business can tolerate in a disaster. Daily backups ensure no more than 24 hours of transaction logs are lost.

### Recovery Time Objective (RTO)
- **Target:** **4 Hours**
- **Definition:** The maximum downtime allowed to restore the system to active status after a disaster.

---

## 🧪 Restore Verification Checks

- **Monthly Drill:** System engineers must perform a mock restore exercise every calendar month.
- **Verification Criteria:** Backups are restored to a staging sandbox database, and test scripts verify that borrower details, active loans, and payment balances match the original records.

---

## 🏢 Roles & Responsibilities

- **System Administrator:** Responsible for configuring automated backups and verifying storage permissions.
- **Lead DevOps Engineer:** Responsible for executing restore procedures during a disaster and documenting performance.
- **Auditor:** Responsible for verifying compliance with data retention requirements.
