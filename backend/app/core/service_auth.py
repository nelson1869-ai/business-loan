"""Machine/service identity authentication dependency for n8n-to-backend API calls."""

import hmac
from typing import Annotated

from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select

from app.core.config import get_settings
from app.core.dependencies import DbSession, bearer_scheme
from app.features.auth.service import TokenValidationError, verify_token
from app.features.users.models import User

bearer = HTTPBearer(auto_error=False)


async def verify_service_account_or_admin(
    db: DbSession,
    credentials: Annotated[
        HTTPAuthorizationCredentials | None, Depends(bearer_scheme)
    ] = None,
    x_service_api_key: Annotated[str | None, Header(alias="X-Service-API-Key")] = None,
) -> User | dict[str, str]:
    """Authenticate machine service accounts or admin users for automation API calls."""
    settings = get_settings()
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or missing service identity credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    # 1. Check API Key matching N8N_SERVICE_API_KEY using constant-time comparison
    if x_service_api_key and settings.n8n_service_api_key:
        if hmac.compare_digest(
            x_service_api_key.strip(), settings.n8n_service_api_key.strip()
        ):
            return {
                "id": "n8n-service-account",
                "role": "service_account",
                "type": "machine",
            }

    # 2. Check JWT Bearer token
    if credentials and credentials.scheme.lower() == "bearer":
        try:
            payload = verify_token(credentials.credentials, "access")
            if (
                payload.get("role") == "service_account"
                or payload.get("sub") == "n8n-service-account"
            ):
                return {
                    "id": payload.get("sub", "n8n-service-account"),
                    "role": "service_account",
                    "type": "machine",
                }
            result = await db.execute(select(User).where(User.id == payload["sub"]))
            user = result.scalar_one_or_none()
            if user and (
                getattr(user, "role", "officer").lower() in ("admin", "manager")
                or user.is_admin
                if hasattr(user, "is_admin")
                else False
            ):
                return user
        except TokenValidationError:
            pass

    raise unauthorized
