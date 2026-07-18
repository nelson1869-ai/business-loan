# Work Progression Flow

This sequence diagram details the work progression and data flows for the Borrower Management implementation.

```mermaid
sequenceDiagram
    Officer->>Form: Input borrower PII details
    Form->>Validator: Check age and national ID rules
    Validator-->>Form: Return validation success
    Form->>LocalDB: Save draft borrower record
```
