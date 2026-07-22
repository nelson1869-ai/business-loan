You are working on "Lending Nelson" — an offline-capable microfinance app built with Flutter (frontend) and FastAPI + PostgreSQL (backend).

The backend is in the `backend/` folder and uses:
- FastAPI with routers in `backend/app/routers/` (admin.py, auth.py, borrowers.py, loans.py, payments.py, sync.py)
- SQLAlchemy models in `backend/app/models/`
- Pydantic schemas in `backend/app/schemas/`
- Business logic in `backend/app/services/`
- Alembic for DB migrations in `backend/alembic/versions/`

The API endpoints are:
POST   /api/v1/auth/token
POST   /api/v1/auth/refresh
GET    /api/v1/borrowers
POST   /api/v1/borrowers
GET    /api/v1/borrowers/{id}
PUT    /api/v1/borrowers/{id}
DELETE /api/v1/borrowers/{id}
GET    /api/v1/loans
POST   /api/v1/loans
GET    /api/v1/loans/{id}
POST   /api/v1/admin/loans/{id}/status
POST   /api/v1/admin/seed
POST   /api/v1/admin/reset
GET    /api/v1/payments
POST   /api/v1/payments/preview
POST   /api/v1/payments/confirm
POST   /api/v1/payments/reverse
POST   /api/v1/sync/drain

Auth uses JWT Bearer tokens. All protected endpoints expect:
  Authorization: Bearer <accessToken>

[YOUR TASK HERE]