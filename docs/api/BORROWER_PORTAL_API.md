# Borrower Portal API Documentation

## Authentication & Security Model
All `/api/v1/client/*` routes require a valid JWT Bearer access token issued specifically for a borrower identity (`aud: "lending_borrower"`).
Officer credentials or mismatched audience tokens are rejected (`401 Unauthorized`).
Borrower identity is strictly derived from `current_account.borrower_id` in token claims; request bodies and query parameters cannot supply `borrowerId`.

---

## Endpoints

### 1. GET `/api/v1/client/dashboard`
Returns read-only summary metrics, active loan counts, total outstanding balance, next payment preview, and recent payment receipt data.

### 2. GET `/api/v1/client/loans`
Returns a paginated collection of borrower-owned loans.

**Query Parameters:**
* `status` (optional, string): Filter by loan status (`active`, `overdue`, `paid`, `cancelled`, `draft`, `defaulted`).
* `offset` (optional, integer >= 0, default 0): Pagination offset.
* `limit` (optional, integer 1..100, default 20): Pagination limit.

**Response (200 OK):**
```json
{
  "items": [
    {
      "id": "loan-uuid",
      "loanReference": "LN-2026-000123",
      "status": "active",
      "principalAmount": "10000.00",
      "totalRepayable": "12000.00",
      "amountPaid": "3500.00",
      "outstandingBalance": "8500.00",
      "installmentAmount": "1000.00",
      "paymentFrequency": "monthly",
      "startDate": "2026-05-01",
      "maturityDate": "2027-05-01",
      "nextDueDate": "2026-08-15",
      "nextPaymentAmount": "1000.00",
      "isOverdue": false,
      "overdueAmount": "0.00",
      "updatedAt": "2026-08-02T10:00:00Z"
    }
  ],
  "total": 1,
  "offset": 0,
  "limit": 20
}
```

---

### 3. GET `/api/v1/client/loans/{loanId}`
Returns detailed financial summary, loan terms, and next installment preview for a specific loan owned by the authenticated borrower.

**Response (200 OK):**
```json
{
  "id": "loan-uuid",
  "loanReference": "LN-2026-000123",
  "status": "active",
  "financialSummary": {
    "principalAmount": "10000.00",
    "interestAmount": "2000.00",
    "feesAmount": "0.00",
    "totalRepayable": "12000.00",
    "amountPaid": "3500.00",
    "outstandingBalance": "8500.00",
    "overdueAmount": "0.00"
  },
  "terms": {
    "paymentFrequency": "monthly",
    "installmentCount": 12,
    "installmentAmount": "1000.00",
    "interestRate": "3.00",
    "startDate": "2026-05-01",
    "maturityDate": "2027-05-01"
  },
  "nextInstallment": {
    "installmentNumber": 5,
    "dueDate": "2026-08-15",
    "amountDue": "1000.00",
    "amountPaid": "0.00",
    "remainingAmount": "1000.00",
    "status": "upcoming"
  },
  "lastUpdated": "2026-08-02T10:00:00Z"
}
```

**Errors:**
* `401 Unauthorized`: Missing or invalid Bearer token / wrong audience / officer token.
* `404 Not Found`: Loan ID does not exist or belongs to another borrower.
* `422 Unprocessable Content`: Invalid query parameters or unsupported status filter.
