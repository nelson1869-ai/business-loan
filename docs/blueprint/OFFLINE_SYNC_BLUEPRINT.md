# Offline Synchronization Blueprint - Lending Nelson

This blueprint details the local storage architecture, queue mechanisms, and conflict resolution rules to ensure robust operation in areas with low or no network coverage.

---

## 💾 Local Database Strategy

The mobile client stores borrower details, active loans, repayment schedules, and system configurations locally. 
- **Offline Cache:** Structured local tables (using SQLite with SQLCipher or Isar) mimic the server schema.
- **Data Retention Limit:** The local cache stores only records relevant to the logged-in User's assigned branch or direct assignments, preventing excessive memory usage and leakage of customer data.

---

## 🗂️ Synchronization Queue & Statuses

Every mutation (creating a borrower, submitting a loan, recording a payment) performed offline is marked with a Sync Status:

| Status | Meaning | Action Needed |
| --- | --- | --- |
| `Synced` | Identical on client and server. | None. |
| `Pending` | Created/modified locally; not sent to server. | Send via sync worker on network recovery. |
| `Error` | Send failed due to validation or server conflict. | Await manual resolution or user override. |

### The Queue Structure
Offline transactions are recorded in an `OfflineQueue` database table:
- `id` (UUID - primary key)
- `endpoint` (String - e.g., `/api/payments`)
- `payload` (String - serialized JSON request body)
- `createdAt` (DateTime)
- `retryCount` (int)
- `transactionUuid` (String - client-generated idempotency key)

---

## ⚔️ Conflict Detection & Resolution

To prevent data corruption, synchronization processes must adhere to strict conflict rules:

### 1. Server-Authoritative Fields
The server remains the ultimate source of truth for:
- Repayment installment statuses (Outstanding, Overdue, Settled).
- Cumulative balances (Total Paid, Total Principal Due).
- Applied penalties (computed server-side based on calendar days late).

### 2. Idempotency & Duplicate Prevention
- **Client Transaction UUID:** Every offline payment generates a unique transaction UUID.
- If the sync worker sends a request and times out, it retries with the same UUID. The server checks its idempotency cache. If the ID exists, it returns `201 Created` with the existing receipt metadata instead of applying a second charge.

### 3. Last-Write-Wins (LWW) vs. Merge Logic
- **Borrower Profile Edits:** Resolved using Last-Write-Wins. The local update timestamp is compared to the server's record, and the latest timestamp is preserved.
- **Financial Modifications:** Financial adjustments (e.g., loan restructuring, payment reversals) are **not permitted offline** to prevent double-spend or ledger inconsistencies. All financial adjustments require active server authorization.

---

## 🔄 Network Restoration Workflow

When the device transitions from offline to online:

1. **Connectivity Listener:** A network listener detects internet restoration.
2. **Sequential Sync Dispatch:** The app reads the `OfflineQueue` ordered by `createdAt` ASC.
3. **HTTP Dispatch:** The app dispatches requests.
   - *On Success (200/201):* Deletes item from queue, updates local DB status to `Synced`.
   - *On Validation Failure (400/422):* Marks item as `Error` and alerts user to review.
   - *On Network Timeout:* Retries with exponential backoff (e.g., 2s, 4s, 8s...) up to a max of 5 retries, then halts the queue until connection stabilizes.
