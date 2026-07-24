"""FastAPI application factory and router registration."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app.config import get_settings
from app.database import AsyncSessionFactory
from app.routers import admin, auth, borrowers, loans, payments, projections, sync


def create_app() -> FastAPI:
    """Create and configure the Lending Nelson API application."""
    settings = get_settings()
    application = FastAPI(title=settings.app_name, version="1.0.0")
    env_lower = settings.app_env.lower()
    is_dev = env_lower in ("development", "dev", "test")

    application.add_middleware(
        CORSMiddleware,
        allow_origins=["*"] if is_dev else settings.cors_origin_list,
        allow_credentials=not is_dev,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Register admin router only in non-production environments
    if is_dev:
        application.include_router(admin.router)

    application.include_router(auth.router)
    application.include_router(borrowers.router)
    application.include_router(loans.router)
    application.include_router(payments.router)
    application.include_router(projections.router)
    application.include_router(sync.router)

    @application.get("/health", tags=["Health"])
    async def health_check() -> dict[str, str]:
        """Return backward-compatible lightweight health status."""
        return {"status": "ok"}

    @application.get("/health/live", tags=["Health"])
    async def liveness_check() -> dict[str, str]:
        """Lightweight liveness check confirming application process is alive.

        Does not query PostgreSQL.
        """
        return {"status": "ok", "service": "lending-nelson-api"}

    @application.get("/health/ready", tags=["Health"])
    async def readiness_check():
        """Readiness check verifying database connectivity and configuration safety."""
        try:
            async with AsyncSessionFactory() as session:
                await session.execute(text("SELECT 1"))
            return {"status": "ready", "service": "lending-nelson-api", "database": "connected"}
        except Exception:
            return JSONResponse(
                status_code=503,
                content={"status": "unavailable", "detail": "Database service unavailable"},
            )

    return application


app = create_app()
