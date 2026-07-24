"""Authentication API routes.

ASCII Flow Diagram
═════════════════════════════════════════════════════════════════════
  LOGIN (POST /api/v1/auth/token)
  ────────────────────────────────────────────────────────────────
  Flutter / Postman
    └─► POST /api/v1/auth/token  { username, password }
          └─► login()                          [this file]
                ├─► authenticate_user()        [auth_service.py]
                │     ├─► SELECT user by username   [models/user.py]
                │     └─► bcrypt.verify(password)
                │
                ├─► ❌ user not found or wrong password
                │     └─► HTTP 401  "Invalid username or password"
                │
                └─► ✅ credentials valid
                      ├─► create_token(user, "access")   [auth_service.py]
                      ├─► create_token(user, "refresh")  [auth_service.py]
                      └─► HTTP 200  { access_token, refresh_token }

  TOKEN REFRESH (POST /api/v1/auth/refresh)
  ────────────────────────────────────────────────────────────────
  Flutter JwtInterceptor (auto) / Postman
    └─► POST /api/v1/auth/refresh  { refresh_token }
          └─► refresh()                          [this file]
                ├─► verify_token(token, "refresh")  [auth_service.py]
                │     ├─► ❌ expired / invalid
                │     │     └─► HTTP 401
                │     └─► ✅ valid → returns JWT claims { sub: user_id }
                │
                ├─► SELECT user by claims["sub"]   [models/user.py]
                │     └─► ❌ user not found → HTTP 401
                │
                └─► ✅ issue a NEW rotated token pair
                      └─► HTTP 200  { access_token, refresh_token }
═════════════════════════════════════════════════════════════════════
"""

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
    # Step 1 — Look up the user by username and verify the bcrypt password hash.
    #          Returns None if the username doesn't exist OR the password is wrong.
    #          We intentionally give the same error for both (no username enumeration).
    user = await authenticate_user(db, payload.username, payload.password)

    # Step 2 — Reject unauthenticated requests with HTTP 401.
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )

    # Step 3 — Issue a short-lived access token (used on every API request)
    #           and a long-lived refresh token (used only to renew the access token).
    #           Both are signed JWTs containing { sub, username, role, type, iat, exp }.
    return TokenResponse(
        access_token=create_token(user, "access"),
        refresh_token=create_token(user, "refresh"),
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh(payload: RefreshTokenRequest, db: DbSession) -> TokenResponse:
    """Exchange a valid refresh token for a rotated token pair."""
    # Step 1 — Decode and validate the incoming JWT.
    #          verify_token() checks the signature, expiry, and that type == "refresh".
    #          Raises TokenValidationError if any check fails.
    try:
        claims = verify_token(payload.refresh_token, "refresh")
    except TokenValidationError as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        ) from error

    # Step 2 — Re-fetch the user from DB using the subject claim (user UUID).
    #          This guards against tokens for deleted/deactivated users.
    result = await db.execute(select(User).where(User.id == claims["sub"]))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    # Step 3 — Rotate: issue a brand-new token pair (old tokens are now obsolete).
    #          Flutter's JwtInterceptor stores both and retries the failed request.
    return TokenResponse(
        access_token=create_token(user, "access"),
        refresh_token=create_token(user, "refresh"),
    )

