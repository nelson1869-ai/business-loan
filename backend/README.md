# Lending Nelson FastAPI backend

Async FastAPI, SQLAlchemy, and PostgreSQL backend for the Lending Nelson Flutter app. Run all commands below from the `backend` directory in PowerShell.

## 1. Bootstrap pip once

Use the Windows `py.exe` launcher to bootstrap pip before creating the virtual
environment:

```powershell
py -m ensurepip --upgrade
py -m pip install --upgrade pip
```

## 2. Create a virtual environment and install dependencies

Create the virtual environment **inside the `backend` directory**. From any
PowerShell location, run:

```powershell
Set-Location D:\Development\lending_nelson\backend
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

This creates the environment at:

```text
D:\Development\lending_nelson\backend\.venv
```

After activation, the PowerShell prompt should begin with `(.venv)`. You can
confirm which Python executable is active with:

```powershell
python -c "import sys; print(sys.executable)"
```

The printed path should end with `backend\.venv\Scripts\python.exe`.

After activation, use `python -m` so every command is guaranteed to run inside
`.venv`. If PowerShell blocks activation, replace `python -m` with
`.\.venv\Scripts\python.exe -m`.

`bcrypt` is intentionally pinned to 4.3.0 because the required Passlib 1.7.4 release is incompatible with bcrypt 5.0's password-length backend probe. The bcrypt wheel uses Python's stable ABI and installs on CPython 3.14.

## 3. Create PostgreSQL database

Install PostgreSQL, start its Windows service, and create an empty database:

```powershell
psql -U postgres -c "CREATE DATABASE lending_nelson;"
```

Copy the environment template and replace the database password and JWT secret:

```powershell
Copy-Item .env.example .env
```

Generate a strong secret without printing application credentials:

```powershell
py -c "import secrets; print(secrets.token_urlsafe(48))"
```

Put that value in `JWT_SECRET_KEY`. Never commit `.env`.

## 4. Run migrations

```powershell
python -m alembic upgrade head
```

The migrations create `users`, `borrowers`, `audit_logs`, `loans`, and
`installments`. The offline queue remains in Flutter's device-local SQLite
database.

## 5. Create the first officer

Use a password of 8-72 UTF-8 bytes. The helper prompts for it securely, hashes it with bcrypt, and never places it in shell history or process arguments:

```powershell
python -m app.bootstrap officer1 --role officer
```

Reset a forgotten development password without deleting the user:

```powershell
officer1
password123
python -m app.bootstrap officer1 --reset-password
```

Enter and confirm the password when prompted. Typed password characters are
intentionally hidden by the terminal.

## 6. Run automated tests (59 Tests)

Run the full backend test suite directly using the virtual environment Python executable:

```powershell
.\.venv\Scripts\python.exe -m unittest discover -s tests
```

Expected output: `Ran 59 tests in 0.233s - OK`

## 7. Run the development server

```powershell
python -m uvicorn app.main:app --reload
```

Open `http://localhost:8000/docs` for Swagger UI or `http://localhost:8000/health` for the health endpoint.

## 7. Run Flutter against the backend

For desktop/web or a directly reachable local target:

```powershell
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

An Android emulator treats `localhost` as the emulator itself. Use the host alias instead:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

For a physical Android device, use the development computer's LAN IP and allow port 8000 through Windows Firewall. Bind Uvicorn to the LAN when needed:

```powershell
python -m uvicorn app.main:app --reload --host 0.0.0.0
```

## API security

- `/api/v1/auth/token` accepts a username/password JSON body.
- `/api/v1/auth/refresh` rotates a refresh token.
- Borrower, loan, and sync endpoints require `Authorization: Bearer <access-token>`.
- `/api/v1/admin/reset` hard-deletes all data tables for development resets.
- `/api/v1/admin/loans/{id}/status` updates loan status and installment due dates for dev seeding.
- Audit JSON always redacts names, national IDs, and phone numbers.
- Development CORS allows all origins; non-development environments use `CORS_ORIGINS`.
- Tokens, passwords, and unredacted audit PII are never logged.
