# Work Progression Flow

This sequence diagram details the work progression and data flows for the Release Preparation implementation.

```mermaid
sequenceDiagram
    Developer->>Gradle: Configure release signing keys
    Developer->>Pubspec: Increment build version code
    Developer->>Terminal: Run flutter build appbundle --release
    Terminal-->>Developer: Signed release bundle created
```
