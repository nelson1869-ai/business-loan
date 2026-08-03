# 100% Free Cloud Hosting Deployment Guide (₱0 / $0 Cost)

This guide walks you through deploying Lending Nelson online for **100% free (₱0 cost)** using free cloud hosting tiers.

---

## 1. Free PostgreSQL Database (Neon.tech or Supabase)

1. Sign up for a free account at [Neon.tech](https://neon.tech) or [Supabase.com](https://supabase.com).
2. Create a new project named `lending-nelson-db`.
3. Copy your connection string:
   ```text
   postgresql+asyncpg://user:password@ep-xyz.neon.tech/neondb?sslmode=require
   ```

---

## 2. Free Backend Web Service (Render.com)

1. Sign up for a free account at [Render.com](https://render.com).
2. Click **New +** ➔ **Web Service**.
3. Connect your GitHub repository (`business-loan`).
4. Configure settings:
   - **Name**: `lending-nelson-backend`
   - **Environment**: `Python 3` (or Docker)
   - **Root Directory**: `backend`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 10000`
5. Under **Environment Variables**, add:
   - `DATABASE_URL`: *(Your connection string from Step 1)*
   - `APP_ENV`: `production`
   - `JWT_SECRET_KEY`: *(Generate a 32+ character random string)*
   - `CORS_ORIGINS`: `["*"]`
6. Click **Create Web Service**. Render will deploy your backend at:
   `https://lending-nelson-backend.onrender.com`

---

## 3. Build Production Mobile Apps (Android APK)

1. Open `lib/core/network/api_client.dart` and `apps/borrower_mobile/lib/core/network/api_client.dart`.
2. Update `baseUrl` to point to your Render backend:
   ```dart
   static const String baseUrl = 'https://lending-nelson-backend.onrender.com';
   ```
3. Build release APKs on your computer:
   ```powershell
   # Officer App APK
   flutter build apk --release

   # Borrower Mobile App APK
   cd apps/borrower_mobile
   flutter build apk --release
   ```
4. Install the generated APKs on your staff and borrower Android phones!
