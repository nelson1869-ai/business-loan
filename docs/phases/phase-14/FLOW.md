# Work Progression Flow

This sequence diagram details the work progression and data flows for the Reports and Analytics implementation.

```mermaid
sequenceDiagram
    Manager->>Reports: View performance stats
    Reports->>LocalDB: Run totals queries
    LocalDB-->>Reports: Returns summary aggregates
    Reports->>Reports: Render charts & KPIs
```
