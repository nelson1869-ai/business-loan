# Work Progression Flow

This sequence diagram details the work progression and data flows for the n8n Workflows and Integrations implementation.

```mermaid
sequenceDiagram
    API->>n8n: Trigger webhook (New Application)
    n8n->>n8n: Run workflow sequence
    n8n->>Email: Deliver signed contract PDF file
```
