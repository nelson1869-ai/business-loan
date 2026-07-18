# System Architecture Overview

This diagram displays the layered Clean Architecture layers from the Flutter UI components to backend storage and external automation services.

```mermaid
graph TD
    subgraph Client [Flutter Mobile Client]
        UI[UI Widgets / Screens]:::planned
        PM[Riverpod State Providers]:::planned
        UC[Application Use Cases]:::planned
        DM[Domain Entities / Interfaces]:::planned
        DT[Data Sources & Repositories]:::planned
        
        UI --> PM
        PM --> UC
        UC --> DM
        DM <--> DT
    end

    subgraph Transport [API Gateway]
        DIO[Dio HTTP Client]:::planned
        SEC[Secure Token Interceptor]:::planned
        DIO --> SEC
    end

    subgraph Backend [Server Infrastructure]
        API[JSON REST API Endpoint]:::future
        SRV[Backend App Server]:::future
        DB[(SQL database / Postgres)]:::future
        
        API --> SRV
        SRV <--> DB
    end

    subgraph External [Automation & Notifications]
        N8N[n8n Workflow Engine]:::future
        SMS[SMS Gateway Service]:::future
        FCM[Push Notifications]:::future
        
        SRV --> N8N
        N8N --> SMS
        N8N --> FCM
    end

    DT <--> DIO
    SEC <--> API

    classDef completed fill:#4CAF50,stroke:#388E3C,color:#fff;
    classDef inprogress fill:#FFC107,stroke:#FFA000,color:#000;
    classDef planned fill:#2196F3,stroke:#1976D2,color:#fff;
    classDef future fill:#9E9E9E,stroke:#616161,color:#fff;
```

## Architectural Status
* **Client Core Layers:** Planned (implemented during Phases 2-3)
* **Transport (Dio):** Planned (implemented during Phase 2)
* **Backend Storage & API:** Future (undecided technology)
* **External Integrations:** Future (n8n workflows)
