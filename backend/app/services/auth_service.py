"""Password verification and JWT token operations."""

from datetime import UTC, datetime, timedelta
from typing import Any, Literal

from jose import JWTError, jwt
from passlib.context import CryptContext
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings, get_settings
from app.models.user import User

password_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class TokenValidationError(ValueError):
    """Raised when a JWT is missing, invalid, expired, or of the wrong type."""


def hash_password(password: str) -> str:
    """Hash a password with bcrypt after enforcing its byte-length limit."""
    if len(password.encode("utf-8")) > 72:
        raise ValueError("Password must not exceed 72 UTF-8 bytes")
    return password_context.hash(password)


def verify_password(password: str, hashed_password: str) -> bool:
    """Compare a plain password with its stored bcrypt hash."""
    if len(password.encode("utf-8")) > 72:
        return False
    return password_context.verify(password, hashed_password)


async def authenticate_user(db: AsyncSession, username: str, password: str) -> User | None:
    """Return the matching user only when the password is valid."""
    result = await db.execute(select(User).where(User.username == username))
    user = result.scalar_one_or_none()
    if user is None or not verify_password(password, user.hashed_password):
        return None
    return user


def create_token(
    user: User,
    token_type: Literal["access", "refresh"],
    settings: Settings | None = None,
) -> str:
    """Create a signed JWT for the supplied user and token type."""
    current_settings = settings or get_settings()
    now = datetime.now(UTC)
    lifetime = (
        timedelta(minutes=current_settings.access_token_expire_minutes)
        if token_type == "access"
        else timedelta(days=current_settings.refresh_token_expire_days)
    )
    payload: dict[str, Any] = {
        "sub": user.id,
        "username": user.username,
        "role": user.role,
        "type": token_type,
        "iat": now,
        "exp": now + lifetime,
    }
    return jwt.encode(
        payload,
        current_settings.jwt_secret_key,
        algorithm=current_settings.jwt_algorithm,
    )


def verify_token(
    token: str,
    expected_type: Literal["access", "refresh"],
    settings: Settings | None = None,
) -> dict[str, Any]:
    """Decode a JWT and require its expected token type."""
    current_settings = settings or get_settings()
    try:
        payload = jwt.decode(
            token,
            current_settings.jwt_secret_key,
            algorithms=[current_settings.jwt_algorithm],
        )
    except JWTError as error:
        raise TokenValidationError("Invalid or expired token") from error
    if payload.get("type") != expected_type or not payload.get("sub"):
        raise TokenValidationError("Invalid token type")
    return payload
