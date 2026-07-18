# Backend API Integration Plan - Lending Nelson

This document describes the structure and design guidelines for the proposed JSON REST API integrated with the mobile client.

---

## 🌐 API Design Standards

- **Protocol:** Enforce HTTPS (TLS 1.3).
- **Format:** JSON request bodies and responses.
- **Headers:**
  - `Content-Type: application/json`
  - `Authorization: Bearer <JWT_ACCESS_TOKEN>`
  - `X-Idempotency-Key: <UUID>` (Mandatory for all POST/PATCH transactions)
- **Pagination:** Enforce pagination on list endpoints (e.g., `/api/borrowers?page=1&limit=20`) using metadata envelopes:
  ```json
  {
    "data": [],
    "meta": {
      "currentPage": 1,
      "totalPages": 5,
      "totalRecords": 100
    }
  }
  ```

---

## 🏷️ Endpoint Modules Summary

The API is structured into the following operational domains (detailed endpoint definitions reside in [ENDPOINT_CATALOG.md](file:///d:/Development/lending_nelson/docs/api/ENDPOINT_CATALOG.md)):

### 1. Identity & Access Management
- **Routes:** `/api/auth/login`, `/api/auth/refresh`, `/api/users/profile`
- Handles user verification, token generation, and role permission validation.

### 2. Borrower Registry
- **Routes:** `/api/borrowers`
- Manages registration of borrowers, profile updates, and physical contact details.

### 3. Loan Products & Configurations
- **Routes:** `/api/products`
- Exposes product limits, interest rates, and fee configurations.

### 4. Loan Lifecycle
- **Routes:** `/api/loans/apply`, `/api/loans/{id}/approve`, `/api/loans/{id}/disburse`
- Manages application submissions, approvals, and disbursement logging.

### 5. Repayments & Receipts
- **Routes:** `/api/payments`, `/api/payments/sync`
- Processes payment submissions, outputs transaction receipts, and tracks repayment schedules.

### 6. Audit & System Logs
- **Routes:** `/api/audit-logs`
- Stores system mutation histories for auditing and compliance tracking.
