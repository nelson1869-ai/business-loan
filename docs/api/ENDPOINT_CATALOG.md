# API Endpoint Catalog - Lending Nelson

This catalog outlines all planned API endpoints. None of these endpoints are currently implemented.

---

## 📋 Planned API Endpoints Registry

| Method | Path | Purpose | Auth Required | Required Role | Request DTO | Response DTO | Planned Phase | Status |
| --- | --- | --- | :---: | --- | --- | --- | :---: | --- |
| **POST** | `/api/auth/login` | Authenticate user & get JWT tokens | No | Any | `LoginRequest` | `AuthResponse` | Phase 4 | Proposed |
| **POST** | `/api/auth/refresh` | Refresh expired JWT access token | No | Any | `RefreshRequest` | `AuthResponse` | Phase 4 | Proposed |
| **GET** | `/api/borrowers` | List paginated borrowers | Yes | Loan Officer, Admin | None | `BorrowerListResponse` | Phase 5 | Proposed |
| **POST** | `/api/borrowers` | Create a new borrower profile | Yes | Loan Officer, Admin | `CreateBorrowerRequest`| `BorrowerDetailResponse`| Phase 5 | Proposed |
| **GET** | `/api/products` | Fetch list of active loan products | Yes | Any | None | `ProductListResponse` | Phase 6 | Proposed |
| **POST** | `/api/loans/apply` | Submit a new loan application | Yes | Loan Officer, Admin | `ApplyLoanRequest` | `ApplicationResponse` | Phase 7 | Proposed |
| **PATCH** | `/api/loans/{id}/approve`| Approve or reject application | Yes | Branch Manager | `ApprovalRequest` | `ApplicationResponse` | Phase 8 | Proposed |
| **POST** | `/api/loans/{id}/disburse`| Disburse approved loan | Yes | Loan Officer, Admin | `DisburseRequest` | `LoanDetailResponse` | Phase 8 | Proposed |
| **GET** | `/api/loans/{id}/schedule`| Retrieve repayment schedule | Yes | Any | None | `ScheduleResponse` | Phase 9 | Proposed |
| **POST** | `/api/payments` | Record a single installment payment | Yes | Cashier, Admin | `PaymentRequest` | `PaymentDetailResponse`| Phase 10 | Proposed |
| **POST** | `/api/payments/sync` | Sync offline-logged payments | Yes | Cashier, Admin | `SyncPaymentsRequest`| `SyncSummaryResponse` | Phase 13 | Proposed |
| **POST** | `/api/audit-logs` | Push offline audit events | Yes | Any | `AuditLogsRequest` | `AuditLogsResponse` | Phase 17 | Proposed |
