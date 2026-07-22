# Local Development Quick Start

Use this page for daily commands. See [backend/README.md](../backend/README.md) and [postman/README.md](../postman/README.md) for full instructions.

## Start everything with the launcher

From the repository root, the preferred daily command is:

```powershell
.\start.ps1 -Target android
```

Supported examples:

```powershell
.\start.ps1 -Target android
.\start.ps1 -Target localhost
.\start.ps1 -Target 192.168.1.50
.\start.ps1 -Target android -Port 8001
```

The launcher validates `backend\.venv`, stops any existing process using the selected port, starts Uvicorn in a separate PowerShell window, checks `/health`, and runs Flutter with the correct `API_BASE_URL`.

**Warning:** `start.ps1` force-stops the process currently listening on the selected port. Use a different `-Port` if that process must remain running.

The target controls the Flutter URL:

| Target | Flutter API URL |
| --- | --- |
| `android` | `http://10.0.2.2:<port>` |
| `ios` or `localhost` | `http://localhost:<port>` |
| LAN IP such as `192.168.1.50` | `http://192.168.1.50:<port>` |

## Start components manually

Use manual startup when you need separate backend and Flutter terminals.

### Backend

```powershell
Set-Location D:\Development\lending_nelson\backend
.\.venv\Scripts\python.exe -m alembic upgrade head
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

| URL | Purpose |
| --- | --- |
| `http://127.0.0.1:8000/health` | Health check |
| `http://127.0.0.1:8000/docs` | Swagger UI |
| `http://127.0.0.1:8000/openapi.json` | API contract |

The API has no `/` route; `{"detail":"Not Found"}` there is expected.

## Development login

```text
username: officer1
password: password123
```

This account is for disposable local development only. Create or reset it securely:

```powershell
.\.venv\Scripts\python.exe -m app.bootstrap officer1 --role officer
.\.venv\Scripts\python.exe -m app.bootstrap officer1 --reset-password
```

Enter passwords only when prompted.

### Flutter

```powershell
Set-Location D:\Development\lending_nelson
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

| Target | API base URL |
| --- | --- |
| Android emulator | `http://10.0.2.2:8000` |
| Windows or web | `http://127.0.0.1:8000` |
| Physical Android device | `http://<computer-LAN-IP>:8000` |

For a physical device, bind Uvicorn to `0.0.0.0` and allow port 8000 only on a trusted development network.

## Verify changes

Flutter:

```powershell
dart format lib test
flutter analyze
flutter test
```

Backend:

```powershell
Set-Location backend
.\.venv\Scripts\python.exe -m compileall app
.\.venv\Scripts\python.exe -m unittest discover -s tests
.\.venv\Scripts\python.exe -m alembic check
```

Postman from the repository root:

```powershell
npx --yes newman run postman\lending-nelson-api.json
```

The Postman suite resets development data. Do not run it against production or irreplaceable data.

## Seed development scenarios

The authenticated Dart seed tool creates sample borrowers plus Active, Overdue, Paid, and Today's Collections scenarios:

```powershell
$env:SEED_USERNAME="officer1"
$env:SEED_PASSWORD="password123"
dart run tool\seed_data.dart --reset
```

`--reset` is destructive. It clears development data before seeding and must never be used against production or irreplaceable data. The documented password is local-development-only; do not store production credentials in scripts or documentation.

## Common failures

| Problem | Check |
| --- | --- |
| `401` | Log in again and use the returned bearer token |
| `404` | Check captured IDs and whether cleanup already ran |
| `409` | Inspect workflow state, idempotency keys, or reversal state |
| `422` | Check OpenAPI field names, UUIDs, dates, enums, and pagination bounds |
| `500` | Inspect Uvicorn logs and PostgreSQL connectivity |
| Android cannot connect | Use `10.0.2.2`, not `localhost` |
