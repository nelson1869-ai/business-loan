"""Authentication request and response schemas."""

from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    """Username and password credentials."""

    username: str = Field(min_length=1, max_length=100)
    password: str = Field(min_length=8, max_length=72)


class RefreshTokenRequest(BaseModel):
    """A refresh token submitted for access-token renewal."""

    refresh_token: str = Field(min_length=1)


class TokenResponse(BaseModel):
    """JWT token pair returned after authentication."""

    access_token: str
    refresh_token: str
    token_type: str = "bearer"
