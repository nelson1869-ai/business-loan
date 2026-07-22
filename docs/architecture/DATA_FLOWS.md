# Application Data Flows

These diagrams describe current behavior. See [System Overview](SYSTEM_OVERVIEW.md) for ownership boundaries.

## Authentication

```mermaid
sequenceDiagram
    actor Officer
    participant Flutter
    participant API as FastAPI auth router
    participant DB as PostgreSQL
    Officer->>Flutter: Enter username and password
    Flutter->>API: POST /api/v1/auth/token
    API->>DB: Verify user and password hash
    API-->>Flutter: Access and refresh tokens
    Flutter->>API: Authenticated request with bearer token
    Flutter->>API: POST /api/v1/auth/refresh after expiry
    API-->>Flutter: Rotated token pair
```

## Loan creation and workflow

```mermaid
sequenceDiagram
    participant Flutter
    participant Router as Loan router
    participant Service as Loan service
    participant DB as PostgreSQL
    Flutter->>Router: POST loan or draft with requestId
    Router->>Service: Validated terms
    Service->>DB: Check idempotency key
    Service->>Service: Calculate exact schedule
    Service->>DB: Persist loan, installments, and audit
    DB-->>Flutter: Loan detail and schedule
    Flutter->>Router: POST workflow action
    Router->>Service: Validate transition
    Service->>DB: Persist lifecycle state and timestamp
```

## Payment, receipt, and statement

```mermaid
sequenceDiagram
    actor Officer
    participant Flutter
    participant API
    participant Service as Payment service
    participant Ledger as PostgreSQL ledger
    Officer->>Flutter: Enter amount and effective date
    Flutter->>API: POST payments/preview
    API->>Service: Calculate allocation
    Service-->>Flutter: Interest, principal, credit, balance
    Officer->>Flutter: Confirm
    Flutter->>API: POST payment with requestId
    Service->>Ledger: Lock, recalculate, append payment and allocation
    Ledger-->>Flutter: Immutable payment response
    Flutter->>API: GET payment receipt
    Flutter->>API: GET loan statement
    API->>Ledger: Project persisted history
    API-->>Flutter: Reconciled receipt and statement
```

## Payment reversal

```mermaid
sequenceDiagram
    participant Flutter
    participant API
    participant Service as Payment service
    participant Ledger
    Flutter->>API: POST reversal with requestId and reason
    API->>Service: Validate latest unreversed payment
    Service->>Ledger: Append linked reversal
    Service->>Ledger: Reconstruct balances and statuses
    Ledger-->>Flutter: Reversal response
    Note over Ledger: Original payment remains unchanged
```

## Dashboard and reports

```mermaid
flowchart LR
    Flutter[Flutter dashboard] --> Endpoint[Projection endpoints]
    Endpoint --> Service[Projection service]
    Service --> Loans[(Loans and installments)]
    Service --> Payments[(Payment and reversal ledger)]
    Service --> Borrowers[(Borrowers)]
    Service --> Result[Dashboard or financial report]
    Result --> Flutter
```

## Offline synchronization

```mermaid
sequenceDiagram
    participant Flutter
    participant Queue as Encrypted SQLite queue
    participant Sync as /api/v1/sync/drain
    participant Services as Backend services
    Flutter->>Queue: Store mutation with transaction UUID and createdAt
    Flutter->>Sync: Submit ordered queue items after reconnect
    Sync->>Services: Dispatch borrower, loan, payment, or reversal request
    Services-->>Sync: Success, idempotent replay, or conflict
    Sync-->>Flutter: Synced UUIDs and failures
    Flutter->>Queue: Remove only confirmed successful items
```

## Debugging path

Trace failures in this order:

1. Flutter screen input and displayed error.
2. Riverpod notifier state.
3. Repository request and local queue record.
4. FastAPI route and Pydantic validation.
5. Backend service rule.
6. PostgreSQL ledger and audit record.
7. Projection reconciliation response.
