"""FastAPI application factory and router registration."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.routers import auth, borrowers, loans, payments, sync


def create_app() -> FastAPI:
    """Create and configure the Lending Nelson API application."""
    settings = get_settings()
    application = FastAPI(title=settings.app_name, version="1.0.0")
    allow_all_origins = settings.app_env.lower() == "development"
    application.add_middleware(
        CORSMiddleware,
        allow_origins=["*"] if allow_all_origins else settings.cors_origin_list,
        allow_credentials=not allow_all_origins,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    application.include_router(auth.router)
    application.include_router(borrowers.router)
    application.include_router(loans.router)
    application.include_router(payments.router)
    application.include_router(sync.router)

    @application.get("/health", tags=["Health"])
    async def health_check() -> dict[str, str]:
        """Return a lightweight service-health response."""
        return {"status": "ok"}

    return application


app = create_app()
