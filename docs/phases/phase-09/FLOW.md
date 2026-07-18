# Work Progression Flow

This sequence diagram details the work progression and data flows for the Repayment Schedules implementation.

```mermaid
sequenceDiagram
    App->>Calculator: Pass principal & rate variables
    Calculator->>Calculator: Generate installments schedule
    Calculator-->>App: Repayments schedule timeline object
    App->>UI: Render installments schedule table
```
