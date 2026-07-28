"""FastAPI application factory and router registration."""

from collections import defaultdict, deque
from time import monotonic

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app.config import get_settings
from app.database import AsyncSessionFactory
from app.routers import (
    admin_assistant,
    auth,
    borrowers,
    business_settings,
    collection_tasks,
    documents,
    loans,
    notes,
    notifications,
    payments,
    projections,
    sync,
    users,
)

_MAX_REQUEST_BYTES = 1_048_576
_LOGIN_WINDOW_SECONDS = 60.0
_MAX_LOGIN_ATTEMPTS = 5


def create_app() -> FastAPI:
    """Create and configure the Lending Nelson API application."""
    settings = get_settings()
    env_lower = settings.app_env.lower()
    is_dev = env_lower in ("development", "dev", "test")
    application = FastAPI(
        title=settings.app_name,
        version="1.0.0",
        debug=False,
        docs_url="/docs" if is_dev else None,
        redoc_url="/redoc" if is_dev else None,
        openapi_url="/openapi.json" if is_dev else None,
    )
    login_attempts: dict[str, deque[float]] = defaultdict(deque)

    application.add_middleware(
        CORSMiddleware,
        allow_origins=["*"] if is_dev else settings.cors_origin_list,
        allow_credentials=not is_dev,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @application.middleware("http")
    async def security_controls(request: Request, call_next):
        """Apply bounded requests, login throttling, and defensive headers."""
        content_length = request.headers.get("content-length")
        if content_length is not None:
            try:
                if int(content_length) > _MAX_REQUEST_BYTES:
                    return JSONResponse(
                        status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                        content={"detail": "Request body too large"},
                    )
            except ValueError:
                return JSONResponse(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    content={"detail": "Invalid Content-Length header"},
                )

        if request.method == "POST" and request.url.path == "/api/v1/auth/token":
            client_host = request.client.host if request.client else "unknown"
            now = monotonic()
            attempts = login_attempts[client_host]
            while attempts and now - attempts[0] >= _LOGIN_WINDOW_SECONDS:
                attempts.popleft()
            if len(attempts) >= _MAX_LOGIN_ATTEMPTS:
                return JSONResponse(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    content={"detail": "Too many login attempts"},
                    headers={"Retry-After": "60"},
                )
            attempts.append(now)

        response = await call_next(request)
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Permissions-Policy"] = (
            "camera=(), microphone=(), geolocation=()"
        )
        if not is_dev:
            response.headers["Strict-Transport-Security"] = (
                "max-age=31536000; includeSubDomains"
            )
        return response

    application.include_router(auth.router)
    application.include_router(admin_assistant.router)
    application.include_router(borrowers.router)
    application.include_router(business_settings.router)
    application.include_router(loans.router)
    application.include_router(notes.router)
    application.include_router(notifications.router)
    application.include_router(collection_tasks.router)
    application.include_router(documents.router)
    application.include_router(payments.router)
    application.include_router(projections.router)
    application.include_router(sync.router)
    application.include_router(users.router)

    @application.get("/health", tags=["Health"])
    async def health_check() -> dict[str, str]:
        """Return backward-compatible lightweight health status."""
        return {"status": "ok"}

    @application.get("/health/live", tags=["Health"])
    async def liveness_check() -> dict[str, str]:
        """Confirm the application process is alive without querying PostgreSQL."""
        return {"status": "ok", "service": "lending-nelson-api"}

    @application.get("/health/ready", tags=["Health"])
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

    return application


app = create_app()
