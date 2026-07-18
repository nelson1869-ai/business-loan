# Work Progression Flow

This sequence diagram details the work progression and data flows for the Payments and Receipts implementation.

```mermaid
sequenceDiagram
    Collector->>UI: Enter payment details
    UI->>LocalDB: Log payment transaction record
    LocalDB->>LocalDB: Adjust active loan outstanding balance
    UI->>ShareSheet: Export transaction receipt PDF
```
