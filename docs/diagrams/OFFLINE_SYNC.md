# Offline Synchronization Architecture

This flowchart outlines the local caching, queueing, and network synchronization path.

```mermaid
flowchart TD
    classDef client fill:#E1F5FE,stroke:#03A9F4,color:#01579B;
    classDef server fill:#EDE7F6,stroke:#673AB7,color:#311B92;
    classDef db fill:#E8F5E9,stroke:#4CAF50,color:#1B5E20;

    subgraph MobileDevice [Mobile Client App]
        LDB[(Local SQLite DB)]:::db
        OQ[Offline Sync Queue]:::client
        LST[Connection Status Listener]:::client
        CONFLICT{Conflict Checker}:::client
        
        LDB -->|Write draft| OQ
    end

    subgraph CloudServer [Server Environment]
        API[Backend REST API Gate]:::server
        S_DB[(Production Postgres Database)]:::db
    end

    LST -->|Internet Connected| OQ
    OQ -->|1. Pop Transaction DTO| CONFLICT
    
    CONFLICT -->|2. Check Last-Modified Timestamp| API
    
    API -->|3. Validate & Process| S_DB
    API -->>|4. Return 200/201 Success| OQ
    OQ -->|5. Update status to Synced| LDB
```
