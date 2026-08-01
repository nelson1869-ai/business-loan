# n8n Automation Architecture & Event Outbox Specification

This document defines the architectural design, security model, data privacy boundaries, versioned event contract, and PostgreSQL event outbox lifecycle for **Lending Nelson**'s n8n automation integration.

---

## 🏗️ System Architecture & Trust Boundaries

```mermaid
flowchart TD
    subgraph Mobile Client ["Flutter Mobile Client (Offline-First)"]
        SQLite["Local SQLite (v11)"]
        OutboxQueue["Offline Sync Outbox"]
    end

    subgraph Backend ["FastAPI Backend Engine"]
        API["FastAPI REST Endpoints"]
        Postgres[(PostgreSQL Database)]
        Outbox[(automation_event_outbox)]
        Signer["HMAC-SHA256 Signer"]
        Worker["Outbox Batch Dispatcher"]
    end

    subgraph n8nServer ["n8n Automation Server"]
        Webhook["Authenticated Inbound Webhook"]
        Router["Domain Event Router"]
        Workflows["Sub-Workflows (Receipts / Reminders / Escalations)"]
    end

    MobileClient -->|1. Sync Mutate (JWT)| API
    API -->|2. Atomic Transaction| Postgres
    API -->|2. Atomic Outbox Event| Outbox
    Worker -->|3. Lock & Read Pending| Outbox
    Worker -->|4. Signed HTTP POST (HMAC)| Webhook
    Webhook --> Router
    Router --> Workflows
    Workflows -->|5. Service API Call (Service Account)| API
```

### Trust Boundary Rules
1. **No Direct Mobile Access:** The Flutter mobile application never connects directly to n8n. Mobile clients interact exclusively with the authenticated FastAPI backend.
2. **Transaction Isolation:** n8n server downtime, HTTP timeouts, or webhook network failures never roll back core financial transactions (loan creation, payment collection, or offline synchronization).
3. **Decoupled Event Outbox:** Domain events are committed to `automation_event_outbox` in the exact same database transaction as business mutations.
4. **Authoritative Source of Truth:** FastAPI and PostgreSQL remain the sole authoritative engines for loan balance calculations, repayment allocations, and state transitions. n8n orchestrates external communications and tasks without modifying financial calculations.

---

## 🔒 Security & HMAC-SHA256 Authentication

Webhooks emitted by FastAPI to n8n are authenticated using HMAC-SHA256 signatures:

### Security Headers
- `X-Lending-Event-Id`: Unique event UUID.
- `X-Lending-Event-Type`: Domain event classification (e.g., `payment.received`).
- `X-Lending-Timestamp`: Unix timestamp (seconds).
- `X-Lending-Signature`: `sha256=` followed by hex digest.
- `X-Lending-Correlation-Id`: Request correlation UUID.

### Signature Formula
$$\text{Signature} = \text{HMAC-SHA256}(\text{Secret}, \text{Timestamp} + "." + \text{RawBody})$$

### Security Constraints
- **Constant-Time Verification:** Webhook endpoints verify signatures using `hmac.compare_digest`.
- **Replay Protection:** Timestamps older than `N8N_SIGNATURE_MAX_AGE_SECONDS` (default 300s) are rejected.
- **Fail-Closed:** Production environments require `N8N_WEBHOOK_SECRET` when `N8N_WEBHOOK_URL` is configured.

---

## 📜 Versioned Event Contract

All automation events use a standardized envelope schema (`DomainEventEnvelope`):

```json
{
  "eventId": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "eventType": "payment.received",
  "eventVersion": 1,
  "occurredAt": "2026-07-31T10:00:00Z",
  "businessTimezone": "Asia/Manila",
  "source": "lending-nelson-api",
  "correlationId": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "idempotencyKey": "payment.received:pay-001",
  "tenantId": null,
  "actor": {
    "id": "user-123",
    "role": "officer"
  },
  "entity": {
    "type": "payment",
    "id": "pay-001"
  },
  "data": {
    "payment_id": "pay-001",
    "loan_id": "loan-001",
    "borrower_id": "bor-001",
    "amount_paid": "1500.00",
    "remaining_balance": "8500.00",
    "effective_date": "2026-07-31"
  }
}
```

---

## 🔄 Outbox Lifecycle & Retry Mechanics

1. **Pending State:** Event inserted with `status = 'pending'`, `attempt_count = 0`, `next_attempt_at = now()`.
2. **Processing State:** Worker fetches pending events using PostgreSQL `FOR UPDATE SKIP LOCKED` and transitions `status = 'processing'`.
3. **Delivered State:** Successful HTTP 2xx response updates `status = 'delivered'`, `delivered_at = now()`.
4. **Exponential Backoff:** HTTP errors or timeouts schedule retries:
   $$\text{Delay} = \text{BaseSeconds} \times 2^{(\text{attempt} - 1)} + \text{Jitter}$$
5. **Dead-Letter State:** Once `attempt_count >= N8N_MAX_ATTEMPTS` (default 8), status updates to `dead_lettered`.
6. **Manual Replay:** Operators can trigger `POST /api/v1/automation/events/{id}/retry` which resets `status = 'pending'`, preserving the original `event_id` and `idempotency_key`.

---

## 🛡️ Data Privacy Rules
- **Redacted Logs:** Passwords, JWT secrets, HMAC keys, and raw request authorization headers are never logged.
- **Minimal PII:** Event payloads transmit only identifiers and non-sensitive attributes. Full phone numbers and borrower details are supplied only where required for authorized notification dispatch.
