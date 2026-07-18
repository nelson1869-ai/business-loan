# Data Flow - Lending Nelson

This document describes the sequence of data transfers and states across the client application, local storage, and the backend service.

---

## 🔄 Loan Lifecycle Data Flow

The following diagram illustrates the standard progression from borrower registration to loan closure.

```mermaid
sequenceDiagram
    autonumber
    actor Officer as Loan Officer
    actor Manager as Branch Manager
    participant App as Mobile App
    participant DB as Local Database (SQLite)
    participant API as Remote Backend API

    Note over Officer, App: Borrower Onboarding
    Officer->>App: Input Borrower PII & Documents
    App->>DB: Store Borrower (Status: Local Draft)
    App->>API: POST /api/borrowers (Upload PII & Docs)
    API-->>App: Return Borrower ID (Status: Synced)
    App->>DB: Update Local Status (Synced)

    Note over Officer, App: Loan Application Submission
    Officer->>App: Select Loan Product & Input Amount
    App->>DB: Create Application Draft
    App->>API: POST /api/loans/apply
    API-->>App: Confirmed (Application Status: Under Review)
    App->>DB: Update Application (Under Review)

    Note over Manager, API: Approval Flow
    Manager->>API: PATCH /api/loans/{id}/approve
    API-->>App: Push Status Change Notification
    App->>DB: Update Status (Approved)

    Note over Officer, App: Loan Disbursement
    Officer->>App: Confirm Cash/Transfer Handover
    App->>DB: Save Disbursement Log
    App->>API: POST /api/loans/{id}/disburse
    API-->>App: Return Repayment Schedule Object
    App->>DB: Write Repayment Schedule (Active)
```

---

## 🛜 Offline Payments Synchronization Flow

When payments are recorded offline, they are queued and synchronized when connectivity is restored.

```mermaid
sequenceDiagram
    autonumber
    actor Collector as Cashier/Collector
    participant App as Mobile App
    participant DB as Local Database (SQLite)
    participant API as Remote Backend API

    Note over Collector, App: Device is Offline
    Collector->>App: Log Repayment Payment ($100)
    App->>App: Generate unique transaction UUID
    App->>DB: Insert Payment Record (Sync Status: Pending)
    App->>DB: Append transaction UUID to Sync Queue
    App-->>Collector: Print/Share Receipt (Marked: Offline Confirmed)

    Note over App, API: Network Connection Restored
    App->>App: Trigger Network Status Listener
    App->>DB: Read next item in Sync Queue
    App->>API: POST /api/payments/sync (includes transaction UUID & details)
    alt Sync Successful
        API-->>App: HTTP 201 Created (Confirmed)
        App->>DB: Update Payment Record (Sync Status: Synced)
        App->>DB: Remove item from Sync Queue
    else Duplicate Request (Already Synced)
        API-->>App: HTTP 409 Conflict (Idempotency Key Found)
        App->>DB: Update Payment Record (Sync Status: Synced)
        App->>DB: Remove item from Sync Queue
    else Server Down / Temp Failure
        API-->>App: HTTP 503 Service Unavailable
        App->>App: Keep item in Sync Queue & Schedule retry backoff
    end
```
