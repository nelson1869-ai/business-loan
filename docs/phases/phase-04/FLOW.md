# Work Progression Flow

This sequence diagram details the work progression and data flows for the Authentication and Authorization implementation.

```mermaid
sequenceDiagram
    User->>LoginScreen: Enter credentials
    LoginScreen->>AuthService: Call Authenticate API
    AuthService-->>LoginScreen: Return JWT Token details
    LoginScreen->>SecureStorage: Write access token
```
