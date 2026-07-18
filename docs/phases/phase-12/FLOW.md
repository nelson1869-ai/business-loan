# Work Progression Flow

This sequence diagram details the work progression and data flows for the Documents and Notifications implementation.

```mermaid
sequenceDiagram
    App->>FilePicker: Pick document image file
    FilePicker-->>App: File byte path details
    App->>LocalDB: Encrypt & write file to secure cache
    App->>Webhook: Trigger SMS notifications dispatch
```
