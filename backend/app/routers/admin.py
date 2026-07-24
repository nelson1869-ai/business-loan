"""Admin-only routes for development tooling."""

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel

from app.config import get_settings
from app.dependencies import CurrentUser, DbSession
from app.services import admin_service

router = APIRouter(prefix="/api/v1/admin", tags=["Admin"])


class LoanStatusUpdate(BaseModel):
    status: str
    dueToday: bool = False


def _verify_dev_environment() -> None:
    """Ensure development endpoints are disabled outside development/test environments."""
    settings = get_settings()
    if settings.app_env.lower() not in ("development", "dev", "test"):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Development admin endpoint is disabled in production",
        )


@router.post("/reset", status_code=status.HTTP_200_OK)
async def reset_all_data(
    db: DbSession,
    current_user: CurrentUser,
) -> dict:
    """Hard-delete all borrowers, loans, payments, and audit logs.

    Intended for the in-app Dev Tools *Delete All Data* button.
    The `users` table is never touched.
    """
    _verify_dev_environment()
    try:
        await admin_service.reset_all_data(db, current_user)
        await db.commit()
        return {"status": "ok", "detail": "All data deleted successfully"}
    except HTTPException:
        raise
    except Exception as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Reset failed due to internal error",
        ) from error


@router.post("/seed", status_code=status.HTTP_200_OK)
async def seed_database(
    db: DbSession,
    current_user: CurrentUser,
) -> dict:
    """Reset and populate the database with sample borrowers, overdue, due today, and paid loans.

    Intended for development tooling and seeding.
    """
    _verify_dev_environment()
    try:
        res = await admin_service.seed_database(db, current_user)
        await db.commit()
        return res
    except HTTPException:
        raise
    except Exception as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Seed failed due to internal error",
        ) from error


@router.post("/loans/{loan_id}/status", status_code=status.HTTP_200_OK)
async def update_loan_status(
    loan_id: str,
    payload: LoanStatusUpdate,
    db: DbSession,
    current_user: CurrentUser,
) -> dict:
    """Update loan status and optionally set first installment due to today."""
    _verify_dev_environment()
    try:
        await admin_service.update_loan_status(
            db, loan_id, payload.status, payload.dueToday
        )
        await db.commit()
        return {
            "status": "ok",
            "detail": f"Loan {loan_id} updated to {payload.status}",
        }
    except HTTPException:
        raise
    except Exception as error:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Update failed due to internal error",
        ) from error
