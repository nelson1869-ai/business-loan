# Production Quick Start

## Backend

```powershell
Set-Location backend
Copy-Item .env.example .env
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Replace every placeholder in `.env` before startup. Terminate TLS at a production reverse proxy and do not expose PostgreSQL or Uvicorn directly to the Internet.

Create the first production user interactively:

```powershell
.\.venv\Scripts\python.exe -m app.bootstrap <username> --role admin
```

## Android release

Provision an untracked production keystore and `android/key.properties`, then build with the public HTTPS API URL:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com
```

## Verification

```powershell
flutter analyze
flutter test
Set-Location backend
.\.venv\Scripts\python.exe -m unittest discover -s tests
.\.venv\Scripts\python.exe -m alembic check
```