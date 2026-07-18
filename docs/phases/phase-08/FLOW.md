# Work Progression Flow

This sequence diagram details the work progression and data flows for the Approval and Disbursement implementation.

```mermaid
sequenceDiagram
    Manager->>Dashboard: Review Application details
    Dashboard->>API: Patch Status to Approved
    API-->>Dashboard: Confirmed
    Officer->>DisbursementForm: Log cash handoff details
```
