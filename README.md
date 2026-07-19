# Lending Nelson

Lending Nelson is an offline-capable microfinance application built with Flutter and a FastAPI/PostgreSQL backend.

New to the project? Follow the [Student Guide](docs/STUDENT_GUIDE.md) for a
layer-by-layer explanation, setup instructions, troubleshooting, and exercises.

## Project structure

```text
lib/       Flutter application
backend/   FastAPI backend and Alembic migrations
test/      Flutter unit and widget tests
```

## Flutter app

Install packages and run the app:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Use `10.0.2.2` from the Android emulator. Use `http://localhost:8000` for Windows or web development.

Run checks:

```powershell
dart format lib test
flutter analyze
flutter test
```

## Python backend

The backend provides JWT authentication, borrower CRUD, redacted audit logging, PostgreSQL persistence, and offline mutation replay.

See [backend/README.md](backend/README.md) for PostgreSQL setup, migrations, first-user creation, and server commands.

The Flutter client expects these endpoints:

```text
POST   /api/v1/auth/token
POST   /api/v1/auth/refresh
GET    /api/v1/borrowers
POST   /api/v1/borrowers
GET    /api/v1/borrowers/{id}
PUT    /api/v1/borrowers/{id}
DELETE /api/v1/borrowers/{id}
POST   /api/v1/sync/drain
```

Do not point Flutter at a different API that exposes `/api/v1/auth/login`; it does not match this app's access/refresh-token contract.

## Security

- Borrower PII is encrypted in device-local SQLite.
- Offline queue payloads are encrypted at rest.
- Backend audit records redact names, national IDs, and phone numbers.
- JWTs and encryption keys are stored using secure storage.
- Secrets belong in `backend/.env`, which must never be committed.
