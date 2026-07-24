# Lending Nelson

Lending Nelson is an offline-capable microfinance client with a Flutter Android application and a FastAPI/PostgreSQL backend.

## Production components

- `lib/`: Flutter application
- `backend/app/`: authenticated lending API
- `backend/alembic/`: PostgreSQL migrations
- `docs/`: retained architecture, deployment, and domain documentation
- `test/` and `backend/tests/`: automated verification

## Required configuration

The backend requires `APP_ENV`, `DATABASE_URL`, `JWT_SECRET_KEY`, and `CORS_ORIGINS`. Copy `backend/.env.example` to an untracked `backend/.env` and replace every placeholder. Production rejects missing environment selection, weak JWT secrets, and wildcard CORS.

Flutter release builds require an HTTPS endpoint:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com
```

Android release signing requires an untracked `android/key.properties` and production keystore. Debug signing is not accepted for release builds.

## Verification

```powershell
flutter analyze
flutter test
Set-Location backend
.\.venv\Scripts\python.exe -m unittest discover -s tests
.\.venv\Scripts\python.exe -m alembic check
```

See [docs/README.md](docs/README.md), [backend/README.md](backend/README.md), and [docs/domain/LOAN_AND_PAYMENT_RULES.md](docs/domain/LOAN_AND_PAYMENT_RULES.md).