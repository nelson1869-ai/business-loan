# Lending Nelson Student Cheat Sheet

Use this page as a quick reference. Read the [Student Guide](STUDENT_GUIDE.md)
when you need the full explanation.

## Project map

| Path | Purpose |
| --- | --- |
| `lib/` | Flutter application |
| `lib/core/` | Shared database, network, and security code |
| `lib/features/` | Screens, providers, and feature repositories |
| `backend/app/` | FastAPI application |
| `backend/alembic/` | PostgreSQL migrations |
| `test/` | Flutter tests |

## Start the backend

Run these commands from `backend/` in PowerShell:

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
python -m alembic upgrade head
python -m uvicorn app.main:app --reload
```

Useful backend addresses:

| Address | Result |
| --- | --- |
| `http://127.0.0.1:8000/health` | Health check |
| `http://127.0.0.1:8000/docs` | Swagger API documentation |
| `http://127.0.0.1:8000/openapi.json` | OpenAPI schema |

`{"detail":"Not Found"}` at `/` is normal because the backend has no root
route. Use `/health` or `/docs` instead.

## Create a login

Local development login:

```text
Username: officer1
Password: <password-created-locally>
```

The repository documents the development username but never stores its real
password. Create or reset the password locally before logging in. Never use or
commit shared default credentials in a production deployment.

From `backend/`:

```powershell
python -m app.bootstrap officer1 --role officer
```

The command asks you to create and confirm a password. It does not provide a
default password. If it reports `Username already exists`, choose another
username, or reset the existing user's password:

```powershell
python -m app.bootstrap officer1 --reset-password
```

## Start Flutter

From the project root:

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Choose the correct backend address:

| Flutter target | API base URL |
| --- | --- |
| Android emulator | `http://10.0.2.2:8000` |
| Windows or web | `http://localhost:8000` |
| Physical Android device | `http://<computer-LAN-IP>:8000` |

For a physical device, start Uvicorn with `--host 0.0.0.0` and allow port 8000
through the computer firewall.

## Quality checks

From the project root:

```powershell
dart format lib test
flutter analyze
flutter test
```

From `backend/`:

```powershell
python -m alembic check
python -m compileall app
```

## Common Git commands

```powershell
git status
git diff
git add <file>
git commit -m "type: short description"
git log --oneline -10
```

Common commit types are `feat`, `fix`, `docs`, `test`, `refactor`, and `chore`.
Never commit `backend/.env`, passwords, tokens, virtual environments, or build
output.

## Common problems

| Problem | Quick check |
| --- | --- |
| Red Dart imports | Run `flutter pub get`, then restart the Dart analysis server |
| Invalid username or password | Confirm the bootstrapped username and password |
| Android cannot connect | Use `10.0.2.2`, not `localhost`, in the emulator |
| HTTP 422 | Check required fields and JSON field names in Swagger `/docs` |
| Database table missing | Run `python -m alembic upgrade head` |
| Port 8000 already used | Stop the old server or start Uvicorn on another port |

## Safe workflow

1. Pull or inspect the latest code.
2. Make one focused change.
3. Format the code.
4. Run analysis and tests.
5. Review `git diff`.
6. Commit with a clear message.
