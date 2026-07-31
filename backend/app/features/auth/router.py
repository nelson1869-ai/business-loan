"""Authentication API routes."""

from fastapi import APIRouter, HTTPException, Request, status
from sqlalchemy import select

from app.core.config import get_settings
from app.core.dependencies import DbSession
from app.features.auth.schemas import LoginRequest, RefreshTokenRequest, TokenResponse
from app.features.auth.service import (
    TokenValidationError,
    authenticate_user,
    create_token,
    verify_token,
)
from app.features.users.models import User
from app.services.rate_limiter import opaque_rate_limit_key

router = APIRouter(prefix="/api/v1/auth", tags=["Authentication"])


@router.post("/token", response_model=TokenResponse)
async def login(
    payload: LoginRequest,
    db: DbSession,
    request: Request,
) -> TokenResponse:
    """Authenticate credentials and return an access/refresh token pair."""
    settings = get_settings()
    client_host = request.client.host if request.client else "unknown"
    limiter_key = opaque_rate_limit_key(
        "login",
        client_host,
        payload.username,
        secret=settings.jwt_secret_key,
    )
    if not await request.app.state.rate_limiter.allow(
        limiter_key,
        settings.login_rate_limit_per_minute,
    ):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many login attempts",
            headers={"Retry-After": "60"},
        )
    user = await authenticate_user(db, payload.username, payload.password)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )
    return TokenResponse(
        access_token=create_token(user, "access"),
        refresh_token=create_token(user, "refresh"),
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh(payload: RefreshTokenRequest, db: DbSession) -> TokenResponse:
    """Exchange a valid refresh token for a rotated token pair."""
    try:
        claims = verify_token(payload.refresh_token, "refresh")
    except TokenValidationError as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        ) from error

    result = await db.execute(select(User).where(User.id == claims["sub"]))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found"
        )
    return TokenResponse(
        access_token=create_token(user, "access"),
        refresh_token=create_token(user, "refresh"),
    )
