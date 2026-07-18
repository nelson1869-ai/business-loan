# Work Progression Flow

This sequence diagram details the work progression and data flows for the Penalties and Collections implementation.

```mermaid
sequenceDiagram
    App->>LocalDB: Query active installments due dates
    LocalDB-->>App: Overdue installments list
    App->>App: Apply late fee calculation
    App->>Collector: Alert with Overdue borrower files list
```
