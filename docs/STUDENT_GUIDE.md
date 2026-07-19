# Lending Nelson Student Guide

For diagram-based learning, open the [Frontend and Backend Visual Flow](VISUAL_FLOW.md).
For focused study, choose the [Flutter frontend](frontend/README.md) or
[FastAPI backend](backend/README.md) path.
Track completed lessons and demonstrations in the
[Student Progress Tracker](progress/README.md).
Future loan, interest, and flexible-payment work is planned in the
[Personal Lending Roadmap](roadmap/README.md).

This guide explains how the Lending Nelson project works and how to run,
study, test, and extend it safely.

## 1. What you will learn

By exploring this project, you can learn how to:

- build a Flutter application with Riverpod and GoRouter;
- connect Flutter to a FastAPI backend with Dio;
- authenticate with access and refresh JSON Web Tokens (JWTs);
- store server data in PostgreSQL using async SQLAlchemy;
- cache data locally in SQLite for offline use;
- encrypt personally identifiable information (PII) on the device;
- queue offline mutations and replay them after reconnection;
- write redacted audit records for data changes;
- manage database changes with Alembic; and
- verify behavior with static analysis and automated tests.

## 2. System architecture

```text
┌──────────────────────── Flutter application ────────────────────────┐
│                                                                    │
│  Screens → Riverpod notifiers → repositories → Dio → FastAPI      │
│                              │                                     │
│                              └──── encrypted SQLite cache/queue    │
└────────────────────────────────────────────────────────────────────┘
                                         │ HTTP + JSON + JWT
                                         ▼
┌──────────────────────── Python backend ─────────────────────────────┐
│                                                                    │
│  FastAPI routers → services → async SQLAlchemy → PostgreSQL        │
│                           └──────────────→ redacted audit logs      │
└────────────────────────────────────────────────────────────────────┘
```

PostgreSQL is the central source of truth. SQLite supports encrypted local
storage and offline work on the device. The Flutter application must never
connect directly to PostgreSQL.

## 3. Important folders

```text
lending_nelson/
├── android/                  Android runner and application settings
├── backend/
│   ├── alembic/              PostgreSQL migrations
│   └── app/
│       ├── models/           SQLAlchemy database models
│       ├── routers/          FastAPI HTTP endpoints
│       ├── schemas/          Pydantic request/response validation
│       └── services/         Authentication and borrower logic
├── lib/
│   ├── app/                  Theme and GoRouter configuration
│   ├── core/                 Database, encryption, and networking
│   └── features/             Feature-first Flutter code
└── test/                     Flutter unit, database, and widget tests
```

## 4. Prerequisites

Install the following tools:

- Flutter stable and the Android SDK;
- Python 3.11 or newer;
- PostgreSQL 16 or newer; and
- Git and PowerShell.

Check Flutter:

```powershell
flutter doctor -v
```

Check Python:

```powershell
python --version
```

## 5. Configure and run the backend

Open PowerShell in the `backend` directory:

```powershell
cd D:\Development\lending_nelson\backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

Copy the environment template:

```powershell
Copy-Item .env.example .env
```

Edit `.env` and supply your PostgreSQL URL and a random JWT secret. Never
commit `.env` or paste its values into documentation.

Run migrations:

```powershell
python -m alembic upgrade head
```

Create a development officer:

```powershell
python -m app.bootstrap officer1 --role officer
```

Enter and confirm a password when prompted. Password characters are hidden by
the terminal.

Start FastAPI:

```powershell
python -m uvicorn app.main:app --reload
```

Useful URLs:

- Health check: `http://127.0.0.1:8000/health`
- OpenAPI JSON: `http://127.0.0.1:8000/openapi.json`
- Swagger UI: `http://127.0.0.1:8000/docs`

## 6. Run the Flutter application

Open a second PowerShell window in the project root:

```powershell
cd D:\Development\lending_nelson
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

`10.0.2.2` is the Android emulator alias for the development computer. For a
Windows or web build running on the same computer, use
`http://localhost:8000`.

The login fields intentionally start empty. Use the officer username and
password you created with the bootstrap command.

## 7. Authentication flow

```text
Login form
   │ username + password
   ▼
POST /api/v1/auth/token
   │
   ├── access token  → added to authenticated API requests
   └── refresh token → obtains a new token pair after expiration
```

Tokens are stored with Flutter Secure Storage. The Dio interceptor attaches
the access token, performs one coordinated refresh after a `401`, and clears
tokens when the session cannot be renewed.

Do not print passwords or JWTs in logs.

## 8. Borrower data flow

The UI does not call Dio or SQLite directly:

```text
Borrower screen
    ▼
BorrowersNotifier
    ├── RemoteBorrowerRepository → FastAPI
    └── BorrowerRepository       → encrypted SQLite
```

When online, a mutation is sent to FastAPI and then stored locally. When
offline, it is stored locally and added to the encrypted sync queue. The queue
is replayed after connectivity returns.

## 9. Backend layers

The backend separates responsibilities:

- **Routers** handle HTTP concerns such as status codes and authentication.
- **Schemas** validate input and serialize output.
- **Services** implement borrower and authentication rules.
- **Models** describe PostgreSQL tables.
- **Alembic** versions database schema changes.

Example request path:

```text
POST /api/v1/borrowers
  → routers/borrowers.py
  → schemas/borrower.py
  → services/borrower_service.py
  → models/borrower.py
  → PostgreSQL
```

## 10. Security lessons

The project demonstrates several important controls:

- PII fields are encrypted before being stored in local SQLite.
- AES-CBC uses a fresh cryptographically random IV for each value.
- Encryption keys and JWTs use platform secure storage.
- Passwords are hashed with bcrypt; plaintext passwords are not stored.
- Backend audit payloads redact names, national IDs, and phone numbers.
- Secrets are loaded from `.env`, which is ignored by Git.
- API endpoints validate field lengths, UUIDs, dates, and allowed statuses.

Encryption does not replace authorization. The backend must still verify the
user for every protected endpoint.

## 11. Run checks and tests

From the project root:

```powershell
dart format lib test
flutter analyze
flutter test
```

Backend checks from `backend`:

```powershell
python -m pip check
python -m alembic check
```

The Flutter suite covers:

- SQLite table creation and operations;
- encryption randomness and legacy decryption;
- borrower repository CRUD, PII encryption, and audit redaction; and
- navigation, login, borrower list, registration, settings, and logout.

## 12. Common problems

### `{"detail":"Not Found"}` at `/`

The API has no root route. Use `/health`, `/docs`, or an `/api/v1/...`
endpoint.

### Android cannot reach FastAPI

Confirm that Uvicorn is running and Flutter uses `10.0.2.2`, not `localhost`.

### `Invalid username or password`

Create an officer with `python -m app.bootstrap ...`. Creating an existing
username does not reset its password.

### HTTP 422

The request reached FastAPI but failed schema validation. Check the field name
and message shown by the app. Date of birth must be a date such as
`2000-01-31`, not a timestamp.

### Database model changed but migration is missing

Generate and inspect an Alembic revision, then apply it:

```powershell
python -m alembic revision --autogenerate -m "describe the change"
python -m alembic upgrade head
```

Never apply an autogenerated migration without reviewing it.

## 13. Suggested student exercises

1. Add client-side validation tests for borrower name, phone, and national ID.
2. Add a borrower detail screen using the existing authenticated API.
3. Add pagination controls for the backend borrower list.
4. Show pending offline mutations in the settings screen.
5. Replace the local audit placeholder user with authenticated user context.
6. Add backend tests for login, token refresh, CRUD, and sync replay.
7. Configure production Android signing without committing the keystore.
8. Add a CI workflow that runs Flutter analysis, Flutter tests, and backend
   checks.

## 14. Rules for safe contributions

- Keep API and database calls outside widgets.
- Put state transitions in Riverpod notifiers.
- Keep business rules in services or domain code.
- Add a migration when the PostgreSQL schema changes.
- Add tests for bug fixes and security behavior.
- Never commit `.env`, passwords, JWTs, encryption keys, or signing keys.
- Run formatting, analysis, and tests before submitting changes.

Start by following one request from the Flutter screen through its notifier,
repository, FastAPI router, service, and database model. That end-to-end trace
is the fastest way to understand this project.
