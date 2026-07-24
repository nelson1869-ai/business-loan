# Lending Nelson &mdash; Full Project Architecture &amp; Learning Map

> **Package ID:** `com.nelson.lending`  
> **Architecture:** Feature-First + Clean Architecture (Flutter) & FastAPI (Python) & PostgreSQL  
> **Printable Study Guides:** Generated in `docs/` folder (Letter 8.5 × 11 in, 3-sheet format)

---

## 🗺️ Step-by-Step Learning Roadmap

```
+-----------------------------------------------------------------------------------+
| STEP 0: App Launch & Session Hydration  [✅ COMPLETED]                           |
|   UI Screen: Splash Screen (/)                                                    |
|   Docs: docs/print_guides/step0_app_launch.html                                                |
|   Frontend: FlutterSecureStorage -> Read JWT -> Auto-Route (/dashboard or /login) |
|   Backend: GET /health Service Ping Check                                         |
+-----------------------------------------------------------------------------------+
                                         │
                                         ▼
+-----------------------------------------------------------------------------------+
| STEP 1: Login & User Authentication Flow  [✅ COMPLETED]                         |
|   UI Screen: Login Screen (/login)                                                |
|   Docs: docs/print_guides/step1_login_flow.html                                                |
|   Frontend: LoginScreen -> LoginNotifier -> AuthRepository -> Dio HTTP           |
|   Backend: POST /api/v1/auth/login -> bcrypt Password Hash -> User SQL Table      |
+-----------------------------------------------------------------------------------+
                                         │
                                         ▼
+-----------------------------------------------------------------------------------+
| STEP 2: Token Refresh & Rotation Flow  [✅ COMPLETED]                             |
|   UI View: Background Interceptor (Triggers on 401 -> Auto-Redirect /login)       |
|   Docs: docs/print_guides/step2_token_refresh.html                                            |
|   Frontend: JwtInterceptor -> 401 Interception -> Token Re-issue -> Request Retry|
|   Backend: POST /api/v1/auth/refresh -> Token Rotation -> User Verification       |
+-----------------------------------------------------------------------------------+
                                         │
                                         ▼
+-----------------------------------------------------------------------------------+
| STEP 3: Borrower Management (Registration & Listing)  [✅ COMPLETED]              |
|   UI Screen: Borrower List Page (/borrowers) & Registration Profile               |
|   Docs: docs/print_guides/step3_borrower_management.html                                       |
|   Frontend: BorrowerListPage -> BorrowerCard -> BorrowerRegistrationForm          |
|   Backend: GET/POST /api/v1/borrowers -> BorrowerService -> Borrower SQL Table   |
+-----------------------------------------------------------------------------------+
                                         │
                                         ▼
+-----------------------------------------------------------------------------------+
| STEP 4: Loan Origination & Calculation Engine  [✅ COMPLETED]                     |
|   UI Screen: Loan Create Screen (/loans/create) & Loans List (/loans)             |
|   Docs: docs/print_guides/step4_loan_origination.html                                          |
|   Frontend: LoanCreateScreen -> LoanDomainCalculators -> Amortization Preview     |
|   Backend: POST /api/v1/loans -> LoanCalculator -> Amortization Schedule -> DB   |
+-----------------------------------------------------------------------------------+
                                         │
                                         ▼
+-----------------------------------------------------------------------------------+
| STEP 5: Payment Collection & Ledger Logging  [NEXT]                               |
|   UI Screen: Payment Collection Screen (/payments) & Today's Collections          |
|   Frontend: PaymentScreen -> PaymentFormCard -> PaymentNotifier -> PaymentRepo    |
|   Backend: POST /api/v1/payments -> PaymentService -> AuditLog Table              |
+-----------------------------------------------------------------------------------+
                                         │
                                         ▼
+-----------------------------------------------------------------------------------+
| STEP 6: Offline Caching & Queue Syncing  [PENDING]                                |
|   UI Screen: Dev Tools / Sync Queue Manager (/dev-tools) & Network Banner         |
|   Frontend: Encrypted SQLite -> OfflineQueue -> OfflineSyncService Drain Mechanism|
|   Backend: POST /api/v1/sync/drain -> Batch Sync Handler -> Conflict Resolution  |
+-----------------------------------------------------------------------------------+
                                         │
                                         ▼
+-----------------------------------------------------------------------------------+
| STEP 7: Portfolio Dashboard & Financial Analytics  [PENDING]                      |
|   UI Screen: Main Dashboard Screen (/dashboard)                                   |
|   Frontend: DashboardPage -> PortfolioSummaryCards -> TodaysCollectionsSection     |
|   Backend: GET /api/v1/projections/summary -> ProjectionService -> Financial Data |
+-----------------------------------------------------------------------------------+
                                         │
                                         ▼
+-----------------------------------------------------------------------------------+
| STEP 8: Security, PII Protection & Data Encryption  [PENDING]                     |
|   UI View: Masked PII Widgets (PiiMaskedText) & Secure Storage Service            |
|   Frontend: AES Encryption -> Masked National ID/Phone -> Secure Key Store        |
|   Backend: Encrypted PII Columns -> Redacted Audit Logging -> Safe Sanity Checks   |
+-----------------------------------------------------------------------------------+
                                         │
                                         ▼
+-----------------------------------------------------------------------------------+
| STEP 9: Admin Overrides, Database Seeding & Diagnostics  [PENDING]                |
|   UI Screen: Dev Tools Page (/dev-tools) & App Settings (/settings)               |
|   Frontend: DevToolsPage -> Queue Inspector -> Database Seeder Button             |
|   Backend: POST /api/v1/admin/seed -> AdminService -> Test Data Generator         |
+-----------------------------------------------------------------------------------+
                                         │
                                         ▼
+-----------------------------------------------------------------------------------+
| STEP 10: Network Client, SSL Pinning & Global Handlers  [PENDING]                 |
|   UI View: Retry Network Banner & Connection Error Snackbars                      |
|   Frontend: ApiClient -> Dio Setup -> SSL Pinning -> Custom Network Exceptions    |
|   Backend: FastAPI CORSMiddleware -> Global Exception Handler -> Pydantic Models  |
+-----------------------------------------------------------------------------------+
                                         │
                                         ▼
+-----------------------------------------------------------------------------------+
| STEP 11: Database Session & Migration Engine  [PENDING]                           |
|   UI View: Local SQLite Schema Migration & Storage State                          |
|   Frontend: DatabaseService -> SQLite Table Schema Setup & Local Migrations       |
|   Backend: database.py -> AsyncSession Generator -> Bootstrap Engine -> SQLAlchemy|
+-----------------------------------------------------------------------------------+
```

---

## 📁 Key File Mapping per Step

### Step 0: App Launch & Session Hydration

- **Postman API Spec**: `GET http://localhost:8000/health` &rarr; `200 OK` (`{"status": "ok"}`)
- **Backend Router**: `backend/app/main.py` (`@application.get("/health")`)
- **Backend Database Session**: `backend/app/database.py` (`create_async_engine()`, `AsyncSessionLocal`)
- **Backend Database Bootstrap**: `backend/app/bootstrap.py` (`init_db()`, `Base.metadata.create_all`)
- **Frontend App Launch**: `lib/main.dart` (`ProviderScope`), `lib/app/app_router.dart`, `lib/features/splash/presentation/splash_screen.dart`

### Step 1: Login & Authentication

- **Postman Collection**: `postman/collections/.../Authentication/Login.request.yaml` (`POST /api/v1/auth/login`)
- **Backend Router**: `backend/app/routers/auth.py` (`POST /api/v1/auth/login`)
- **Backend Service**: `backend/app/services/auth_service.py` (`authenticate_user()`, `bcrypt.verify()`)
- **SQL Model**: `backend/app/models/user.py` (`User` table, `password_hash`, `role`)
- **Frontend UI Screen**: `LoginScreen` (`/login`), `lib/features/auth/presentation/login_screen.dart`
- **Frontend State Provider**: `lib/features/auth/presentation/providers/login_notifier.dart`
- **Frontend HTTP Repository**: `lib/features/auth/data/auth_repository.dart`

### Step 2: Token Refresh & Rotation

- **Postman Collection**: `postman/collections/.../Authentication/Refresh Token.request.yaml` (`POST /api/v1/auth/refresh`)
- **Backend Router**: `backend/app/routers/auth.py` (`POST /api/v1/auth/refresh`)
- **Backend Service**: `backend/app/services/auth_service.py` (`verify_token()`, JWT rotation)
- **SQL Model**: `backend/app/models/user.py` (`User` table)
- **Frontend Interceptor**: `lib/core/network/api_client.dart` (`JwtInterceptor`, 401 automatic retry)
- **Frontend Storage**: `FlutterSecureStorage` (`access_token`, `refresh_token`)

### Step 3: Borrower Management

- **Postman Collection**: `postman/collections/.../Borrowers/Create Borrower.request.yaml` (`GET/POST /borrowers`)
- **Backend Router**: `backend/app/routers/borrowers.py` (`GET /borrowers`, `POST /borrowers`)
- **Backend Service**: `backend/app/services/borrower_service.py` (PII column masking & validation)
- **SQL Model**: `backend/app/models/borrower.py` (`Borrower` table, encrypted national ID)
- **Frontend UI Screen**: `BorrowerListPage` (`/borrowers`), `BorrowerDetailPage` (`/borrowers/:id`), `BorrowerRegistrationPage`
- **Frontend State & Widgets**: `lib/features/borrowers/widgets/borrower_card.dart`, `borrower_registration_form.dart`, `pii_masked_text.dart`

### Step 4: Loan Origination & Calculation Engine

- **Postman Collection**: `postman/collections/.../Loans/Create Loan.request.yaml` (`POST /loans`, `GET /loans`)
- **Backend Router**: `backend/app/routers/loans.py` (`POST /loans`, `GET /loans`)
- **Backend Calculator / Service**: `backend/app/services/loan_calculator.py`, `loan_service.py` (Amortization engine)
- **SQL Model**: `backend/app/models/loan.py` (`Loan`, `LoanInstallment` tables)
- **Frontend UI Screen**: `LoanCreateScreen` (`/borrowers/:borrowerId/loans/new`), `LoansListPage` (`/loans`), `LoanDetailScreen`
- **Frontend State & Domain**: `lib/features/loans/presentation/providers/loan_create_notifier.dart`, `loan.dart`, `installment.dart`

### Step 5: Payment Collection & Ledger Logging

- **Postman Collection**: `postman/collections/.../Payments/Collect Payment.request.yaml` (`POST /payments`)
- **Backend Router**: `backend/app/routers/payments.py` (`POST /payments`)
- **Backend Service**: `backend/app/services/payment_service.py` (Ledger balance updates & audit creation)
- **SQL Models**: `backend/app/models/payment.py` (`Payment` table), `audit_log.py` (`AuditLog` table)
- **Frontend UI Screen**: `PaymentScreen` (`/loans/:loanId/payments`), `TodaysCollectionsPage` (`/collections/today`)
- **Frontend State & Repository**: `lib/features/loans/presentation/providers/payment_notifier.dart`, `remote_payment_repository.dart`

### Step 6: Offline Caching & Queue Syncing

- **Postman Collection**: `postman/collections/.../Sync/Drain Queue.request.yaml` (`POST /api/v1/sync/drain`)
- **Backend Router**: `backend/app/routers/sync.py` (`POST /api/v1/sync/drain`)
- **Backend Service**: Batch sync conflict resolution & idempotent transaction handlers
- **SQL Models**: `backend/app/models/audit_log.py`, SQLite local `offline_queue` table
- **Frontend Local DB & Sync**: `lib/core/database/database_service.dart` (SQLite), `lib/core/network/offline_sync_service.dart`

### Step 7: Portfolio Dashboard & Analytics

- **Postman Collection**: `postman/collections/.../Analytics/Dashboard Summary.request.yaml` (`GET /api/v1/projections/summary`)
- **Backend Router**: `backend/app/routers/projections.py` (`GET /api/v1/projections/summary`)
- **Backend Service**: `backend/app/services/projection_service.py` (Portfolio At Risk PAR 30/60/90, Cashflow projection)
- **SQL Analytics Queries**: Aggregate query join on `loans`, `installments`, and `payments`
- **Frontend UI Screen**: `DashboardPage` (`/dashboard`), `PortfolioSummaryCards`, `TodaysCollectionsSection`

### Step 8: Security, PII Protection & Data Encryption

- **Backend Security System**: Password Hashing (`passlib`/`bcrypt`), JWT RS256 token verification
- **Backend Audit System**: `AuditLog` table ([audit_log.py](file:///d:/Development/lending_nelson/backend/app/models/audit_log.py))
- **Frontend Security Service**: `lib/core/security/encryption_service.dart` (AES-256 Encryption)
- **Frontend Storage**: `FlutterSecureStorage` (stores encryption keys)

### Step 9: Admin Services, Seeding & Diagnostics

- **Postman Collection**: `postman/collections/.../Admin/Seed Database.request.yaml` (`POST /api/v1/admin/seed`)
- **Backend Router**: `backend/app/routers/admin.py` (`POST /api/v1/admin/seed`, `GET /api/v1/admin/health`)
- **Backend Service**: `backend/app/services/admin_service.py` (Database seeder & reset engine)
- **Frontend Diagnostics View**: `DevToolsPage` (`/dev-tools`), `SettingsPage` (`/settings`)

### Step 10: Network Client, SSL Pinning & Global Handlers

- **Backend Infrastructure**: `backend/app/main.py` (`CORSMiddleware`, FastAPI exception handlers, Pydantic error formatting)
- **Frontend Core Network**: `lib/core/network/api_client.dart` (`ApiClient`, Dio setup, SSL Certificate Pinning)
- **Frontend Endpoints**: `lib/core/network/api_endpoints.dart`

### Step 11: Database Session & Migration Engine

- **Backend Database Infrastructure**: `backend/app/database.py` (`AsyncSession` generator) & `backend/app/bootstrap.py` (SQLAlchemy schema initialization)
- **Frontend Core Database**: `lib/core/database/database_service.dart` & `database_provider.dart` (SQLite schema versioning)

---

## 💡 How to Study Each Step

1. Open the **Printable HTML Document** in `docs/` (e.g. `docs/step1_login_flow.html`).
2. Press **`Ctrl + P`** in Chrome &rarr; Set to Letter size &rarr; Print or view.
3. Review the code layer-by-layer: **Postman &rarr; Flutter UI &rarr; Flutter State &rarr; Dio HTTP &rarr; Backend FastAPI &rarr; SQL**.
