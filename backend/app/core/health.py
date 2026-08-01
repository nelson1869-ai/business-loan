"""Process and database health endpoints."""

from fastapi import APIRouter
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app.core.database import AsyncSessionFactory

router = APIRouter(tags=["Health"])


@router.get("/health")
async def health_check() -> dict[str, str]:
    """Return backward-compatible lightweight health status."""
    return {"status": "ok"}


@router.get("/health/live")
async def liveness_check() -> dict[str, str]:
    """Confirm the process is alive without querying PostgreSQL."""
    return {"status": "ok", "service": "lending-nelson-api"}


@router.get("/health/ready")
async def readiness_check():
    """Verify database connectivity without exposing exception details."""
    try:
        async with AsyncSessionFactory() as session:
            await session.execute(text("SELECT 1"))
        return {
            "status": "ready",
            "service": "lending-nelson-api",
            "database": "connected",
        }
    except Exception:
        return JSONResponse(
            status_code=503,
            content={
                "status": "unavailable",
                "detail": "Database service unavailable",
            },
        )
