"""Authentication API routes."""

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from app.dependencies import DbSession
from app.models.user import User
from app.schemas.auth import LoginRequest, RefreshTokenRequest, TokenResponse
from app.services.auth_service import (
    TokenValidationError,
    authenticate_user,
    create_token,
    verify_token,
)

router = APIRouter(prefix="/api/v1/auth", tags=["Authentication"])


@router.post("/token", response_model=TokenResponse)
async def login(payload: LoginRequest, db: DbSession) -> TokenResponse:
    """Authenticate credentials and return an access/refresh token pair."""
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
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return TokenResponse(
        access_token=create_token(user, "access"),
        refresh_token=create_token(user, "refresh"),
    )
