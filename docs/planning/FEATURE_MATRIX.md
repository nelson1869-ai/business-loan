# Feature Matrix - Lending Nelson

This table details the feature availability across platforms, technical dependencies, priority, and implementation schedules.

| Feature | Mobile App | Web Admin | Backend Required | Offline Support | Role Restrictions | Priority | Planned Phase | Status |
| --- | :---: | :---: | :---: | :---: | --- | :---: | :---: | --- |
| **User Authentication** | Yes | Yes | Yes | Limited (PIN/Biometric) | None | High | Phase 4 | Not Started |
| **Register Borrower** | Yes | Yes | Yes | Yes | Loan Officer, Admin | High | Phase 5 | Not Started |
| **Manage Loan Products** | Read-only | Yes | Yes | Cache only | Admin | Medium | Phase 6 | Not Started |
| **Submit Loan App** | Yes | Yes | Yes | Yes | Loan Officer, Admin | High | Phase 7 | Not Started |
| **Approve / Reject Loan** | No | Yes | Yes | No | Branch Manager, Admin | High | Phase 8 | Not Started |
| **Record Repayments** | Yes | Yes | Yes | Yes | Cashier, Admin | High | Phase 10 | Not Started |
| **Late Penalties Calc** | No | Yes | Yes | No (Server side) | System (Automated) | Medium | Phase 11 | Not Started |
| **Collection Logging** | Yes | Yes | Yes | Yes | Collector, Admin | Medium | Phase 11 | Not Started |
| **Print / Share Receipts** | Yes | No | No | Yes (cached PDF) | Cashier | High | Phase 10 | Not Started |
| **Document Upload** | Yes | Yes | Yes | Yes (delayed upload) | Loan Officer, Admin | Medium | Phase 12 | Not Started |
| **Offline Sync Queue** | Yes | No | Yes | Core Engine | System | High | Phase 13 | Not Started |
| **Analytics Dashboard** | Yes | Yes | Yes | Yes (local data) | Branch Manager, Admin | Low | Phase 14 | Not Started |
| **n8n Automation Webhooks**| No | Yes | Yes | No | Admin | Low | Phase 16 | Not Started |
