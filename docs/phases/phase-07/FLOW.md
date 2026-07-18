# Work Progression Flow

This sequence diagram details the work progression and data flows for the Loan Application Workflow implementation.

```mermaid
sequenceDiagram
    Officer->>Form: Select borrower and product
    Form->>Form: Validate amount requested
    Form->>LocalDB: Save application draft status
```
