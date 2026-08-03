# 100% Free Cloud Production Deployment Guide (₱0 / $0 Cost)

This guide documents the production deployment architecture for Lending Nelson using Render Free, Supabase Free, and wireless mobile testing.

---

## 1. Cloud Architecture Overview

- **Backend**: Render Free (FastAPI in Docker runtime)
- **Database**: Supabase Free (PostgreSQL via SQLAlchemy 2 Async & Alembic)
- **Live Backend API**: `https://lending-nelson-api.onrender.com`
- **Mobile Apps**: Flutter Officer App (`lib/`) & Borrower Mobile App (`apps/borrower_mobile`)

---

## 2. Live Cloud Environment Variables (Render Web Service)

```bash
APP_ENV=production
DATABASE_URL=postgresql+asyncpg://postgres:[PASSWORD]@db.[REF].supabase.co:5432/postgres?ssl=require
JWT_SECRET_KEY=<64_CHARACTER_RANDOM_HEX>
CORS_ORIGINS=["https://lending-nelson-api.onrender.com"]
LOCAL_BORROWER_OTP_ENABLED=false
N8N_WEBHOOK_SECRET=<YOUR_WEBHOOK_SECRET>
```

---

## 3. First Administrator Bootstrap

Run the native CLI bootstrap script against your production database:

```powershell
Set-Location backend

$env:APP_ENV="production"
$env:DATABASE_URL="postgresql+asyncpg://postgres:[PASSWORD]@db.[REF].supabase.co:5432/postgres?ssl=require"
$env:JWT_SECRET_KEY="<YOUR_SECRET_KEY>"
$env:CORS_ORIGINS="https://lending-nelson-api.onrender.com"
$env:LOCAL_BORROWER_OTP_ENABLED="false"
$env:N8N_WEBHOOK_SECRET="<YOUR_WEBHOOK_SECRET>"

.\.venv\Scripts\python.exe -m app.bootstrap nelson --role admin
```

---

## 4. Launching Mobile Apps on Personal Phone (Wireless ADB)

### Option A: Connect Phone Wirelessly to Live Render Cloud
```powershell
.\start-phone.ps1 -UseRender
```
- Automatically connects over Wi-Fi via ADB wireless debugging.
- Configures apps to communicate directly with `https://lending-nelson-api.onrender.com`.
- **Works 24/7 even after you turn off your PC!**

### Option B: Connect Phone Wirelessly to Local PC Backend
```powershell
.\start-phone.ps1
```

---

## 5. Standalone APK Release Builds

```powershell
# Officer App Production Release APK
flutter build apk --release `
  --flavor production `
  --target lib/main.dart `
  --dart-define=APP_ENV=production `
  --dart-define=API_BASE_URL=https://lending-nelson-api.onrender.com `
  --dart-define=LOCAL_BORROWER_OTP_ENABLED=false

# Borrower Mobile App Production Release APK
Set-Location apps\borrower_mobile
flutter build apk --release `
  --flavor production `
  --target lib/main.dart `
  --dart-define=APP_ENV=production `
  --dart-define=API_BASE_URL=https://lending-nelson-api.onrender.com `
  --dart-define=LOCAL_BORROWER_OTP_ENABLED=false
```

---

## 6. Cold-Start Behavior & Uptime Monitoring

Render Free instances enter sleep mode after 15 minutes of zero traffic.  
- **Initial Cold-Start Request**: Takes ~20–30 seconds to wake the service.
- **Subsequent Requests**: Respond in ~100–200ms.
- **Continuous 24/7 Uptime**: Ping `https://lending-nelson-api.onrender.com/health` every 10 minutes via [UptimeRobot](https://uptimerobot.com) to prevent sleeping.
