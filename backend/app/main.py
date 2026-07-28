"""FastAPI application factory."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import register_routers
from app.config import get_settings
from app.middleware.request_limits import install_request_limits
from app.middleware.security import install_security_headers
from app.services.rate_limiter import build_rate_limiter


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
    application.state.rate_limiter = build_rate_limiter(
        settings.assistant_rate_limit_redis_url
    )

    application.add_middleware(
        CORSMiddleware,
        allow_origins=["*"] if is_dev else settings.cors_origin_list,
        allow_credentials=not is_dev,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    install_request_limits(application)
    install_security_headers(application, production=not is_dev)
    register_routers(application)

    return application


app = create_app()
