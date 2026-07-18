# Work Progression Flow

This sequence diagram details the work progression and data flows for the Loan Product Configuration implementation.

```mermaid
sequenceDiagram
    Officer->>App: View Loan Products list
    App->>LocalCache: Query products details
    LocalCache-->>App: Return list of product rules
    App->>Officer: Display limits & rates screen
```
