# Frontend and Backend Visual Flow

This document shows how the Flutter frontend and FastAPI backend work together.
Follow the arrows to understand which file or layer receives data next.

## 1. Whole system

```mermaid
flowchart LR
    User[Student or loan officer] --> UI[Flutter screens]
    UI --> State[Riverpod providers]
    State --> Local[Encrypted SQLite]
    State --> API[Dio API client]
    API --> FastAPI[FastAPI routes]
    FastAPI --> Services[Backend services]
    Services --> PG[(PostgreSQL)]
    Services --> Audit[(Audit logs)]
```

The frontend never connects directly to PostgreSQL. FastAPI is the security and
validation boundary between the mobile app and the central database.

## 2. Flutter frontend layers

```mermaid
flowchart TD
    Screens[Presentation<br/>screens and forms]
    Providers[Application state<br/>Riverpod providers]
    Repositories[Data layer<br/>local and remote repositories]
    SQLite[(Local SQLite)]
    SecureStorage[(Secure token storage)]
    Dio[Dio HTTP client]

    Screens -->|user action| Providers
    Providers --> Repositories
    Repositories -->|offline data| SQLite
    Repositories -->|API request| Dio
    Dio <--> SecureStorage
    Providers -->|new state| Screens
```

Important frontend locations:

| Layer | Location | Responsibility |
| --- | --- | --- |
| Screens | `lib/features/**/presentation/` | Displays data and collects input |
| State | `presentation/providers/` | Coordinates loading and mutations |
| Local data | `borrower_repository.dart` | Encrypts and stores SQLite rows |
| Remote data | `remote_borrower_repository.dart` | Sends borrower API requests |
| Networking | `lib/core/network/` | Base URL, tokens, retries, and sync queue |

## 3. FastAPI backend layers

```mermaid
flowchart TD
    Request[HTTP request]
    Router[FastAPI router]
    Dependency[Authentication and DB dependencies]
    Schema[Pydantic schema validation]
    Service[Business service]
    Model[SQLAlchemy model]
    Database[(PostgreSQL)]
    Response[JSON response]

    Request --> Router
    Router --> Dependency
    Router --> Schema
    Dependency --> Service
    Schema --> Service
    Service --> Model
    Model --> Database
    Database --> Model
    Model --> Schema
    Schema --> Response
```

Important backend locations:

| Layer | Location | Responsibility |
| --- | --- | --- |
| Application | `backend/app/main.py` | Creates FastAPI and registers routers |
| Routers | `backend/app/routers/` | Defines URLs and HTTP responses |
| Schemas | `backend/app/schemas/` | Validates request and response data |
| Services | `backend/app/services/` | Applies business rules and audit logging |
| Models | `backend/app/models/` | Maps Python objects to PostgreSQL tables |
| Migrations | `backend/alembic/` | Versions database structure changes |

## 4. Login flow

```mermaid
sequenceDiagram
    actor User
    participant Login as Flutter login screen
    participant Auth as AuthRepository
    participant API as FastAPI /api/v1/auth/token
    participant DB as PostgreSQL
    participant Storage as Secure storage

    User->>Login: Enter username and password
    Login->>Auth: login(username, password)
    Auth->>API: POST credentials
    API->>DB: Find user and verify password hash
    DB-->>API: User record
    API-->>Auth: Access and refresh tokens
    Auth->>Storage: Save tokens
    Auth-->>Login: Success
    Login-->>User: Open dashboard
```

Plain passwords are sent only to the login endpoint and are not persisted by
Flutter or PostgreSQL. PostgreSQL stores a password hash.

## 5. Register borrower flow

```mermaid
sequenceDiagram
    actor User
    participant Form as Borrower form
    participant Provider as BorrowersNotifier
    participant Remote as Remote repository
    participant API as FastAPI borrowers route
    participant PG as PostgreSQL
    participant Local as Encrypted SQLite

    User->>Form: Enter and submit details
    Form->>Provider: registerBorrower
    Provider->>Remote: POST borrower
    Remote->>API: /api/v1/borrowers
    API->>PG: Insert borrower and audit log
    PG-->>API: Created borrower
    API-->>Remote: HTTP success
    Provider->>Local: Encrypt and save borrower
    Provider-->>Form: Refresh state
    Form-->>User: Registration successful
```

## 6. Edit borrower flow

```mermaid
flowchart TD
    Edit[User presses Save Changes] --> Put[PUT borrower to FastAPI]
    Put --> Exists{Borrower exists<br/>in PostgreSQL?}
    Exists -->|Yes| Update[Update PostgreSQL and audit log]
    Exists -->|No, legacy local row| Create[Create matching remote borrower]
    Update --> Local[Update encrypted SQLite row]
    Create --> Local
    Local --> UI[Refresh borrower list]
```

The fallback path migrates borrowers created by older app versions that stored
records only in SQLite.

## 7. Offline mutation flow

```mermaid
flowchart TD
    Action[Create, edit, or delete] --> Network{Network available?}
    Network -->|Yes| Backend[Send request to FastAPI]
    Backend --> Success{Request successful?}
    Success -->|Yes| SaveOnline[Update encrypted SQLite]
    Success -->|Temporary failure| Queue[Save operation in sync queue]
    Network -->|No| SaveOffline[Update encrypted SQLite]
    SaveOffline --> Queue
    SaveOnline --> Done[Refresh UI]
    Queue --> Later{Connection restored?}
    Later -->|Yes| Replay[Replay queued API request]
    Replay --> Backend
```

SQLite lets the officer keep working without internet. PostgreSQL remains the
central shared database, so queued changes must eventually synchronize.

## 8. Payment flow

```mermaid
flowchart TD
    Entry[Officer enters amount and effective date] --> Preview[FastAPI preview]
    Preview --> Review{Officer confirms?}
    Review -->|No| Entry
    Review -->|Yes| Lock[PostgreSQL locks loan]
    Lock --> Recalculate[FastAPI recalculates allocation]
    Recalculate --> Interest[Apply accrued interest]
    Interest --> Principal[Apply remaining money to principal]
    Principal --> Credit[Keep excess as unapplied credit]
    Credit --> Commit[Commit ledger, balances, and audit together]
    Commit --> History[Flutter refreshes loan and payment history]
```

## 9. Student debugging path

```mermaid
flowchart LR
    UIError[Error shown in Flutter] --> FlutterLogs[Read Flutter terminal]
    FlutterLogs --> Request[Check API URL and request]
    Request --> Swagger[Test endpoint in /docs]
    Swagger --> BackendLogs[Read Uvicorn output]
    BackendLogs --> Database[Check migration and PostgreSQL]
```

Debug one layer at a time. First confirm the UI input, then the API address,
the backend response, and finally the database state.
