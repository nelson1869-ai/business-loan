"""Admin-only routes for development tooling."""

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from app.dependencies import CurrentUser, DbSession
from app.services import admin_service

router = APIRouter(prefix="/api/v1/admin", tags=["Admin"])


class LoanStatusUpdate(BaseModel):
    status: str
    dueToday: bool = False


@router.post("/reset", status_code=status.HTTP_200_OK)
async def reset_all_data(
    db: DbSession,
    current_user: CurrentUser,
) -> dict:
    """Hard-delete all borrowers, loans, payments, and audit logs.

    Intended for the in-app Dev Tools *Delete All Data* button.
    The `users` table is never touched.
    """
    try:
        await admin_service.reset_all_data(db, current_user)
        await db.commit()
        return {"status": "ok", "detail": "All data deleted successfully"}
    except Exception as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Reset failed: {error}",
        ) from error


@router.post("/seed", status_code=status.HTTP_200_OK)
async def seed_database(
    db: DbSession,
    current_user: CurrentUser,
) -> dict:
    """Reset and populate the database with sample borrowers, overdue, due today, and paid loans.

    Intended for development tooling and seeding.
    """
    try:
        res = await admin_service.seed_database(db, current_user)
        await db.commit()
        return res
    except Exception as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Seed failed: {error}",
        ) from error


@router.post("/loans/{loan_id}/status", status_code=status.HTTP_200_OK)
async def update_loan_status(
    loan_id: str,
    payload: LoanStatusUpdate,
    db: DbSession,
    current_user: CurrentUser,
) -> dict:
    """Update loan status and optionally set first installment due to today."""
    try:
        await admin_service.update_loan_status(
            db, loan_id, payload.status, payload.dueToday
        )
        await db.commit()
        return {
            "status": "ok",
            "detail": f"Loan {loan_id} updated to {payload.status}",
        }
    except Exception as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Update failed: {error}",
        ) from error

