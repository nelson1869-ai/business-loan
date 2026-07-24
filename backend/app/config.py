"""Environment-backed application configuration."""

from functools import lru_cache

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

ALLOWED_ENVIRONMENTS = {"development", "dev", "test", "staging", "production", "prod"}
WEAK_SECRETS = {
    "secret",
    "change-me",
    "changeme",
    "supersecret",
    "supersecretkey",
    "12345678901234567890123456789012",
    "0123456789abcdef0123456789abcdef",
    "your_jwt_secret_key_here_must_be_32_bytes_min",
}


class Settings(BaseSettings):
    """Validated settings loaded from environment variables and `.env`."""

    app_name: str = "Lending Nelson API"
    app_env: str
    database_url: str
    jwt_secret_key: str = Field(min_length=32)
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = Field(default=15, gt=0)
    refresh_token_expire_days: int = Field(default=7, gt=0)
    cors_origins: str

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    @field_validator("app_env")
    @classmethod
    def validate_app_env(cls, value: str) -> str:
        """Validate allowed application environments."""
        env = value.lower().strip()
        if env not in ALLOWED_ENVIRONMENTS:
            raise ValueError(
                f"Invalid APP_ENV '{value}'. Allowed: {', '.join(sorted(ALLOWED_ENVIRONMENTS))}"
            )
        return env

    @field_validator("jwt_secret_key")
    @classmethod
    def validate_jwt_secret_key(cls, value: str, info) -> str:
        """Reject obvious placeholder or low-quality JWT secrets."""
        val_lower = value.lower().strip()
        if (
            val_lower in WEAK_SECRETS
            or val_lower.startswith(("change-me", "replace-with", "your-"))
            or len(set(value)) < 12
        ):
            raise ValueError(
                "JWT_SECRET_KEY must be a strong, random value and cannot be a placeholder."
            )
        return value

    @field_validator("cors_origins")
    @classmethod
    def validate_cors_origins(cls, value: str, info) -> str:
        """Reject wildcard CORS in production environments."""
        env = info.data.get("app_env", "").lower().strip()
        if env in ("production", "prod") and value.strip() == "*":
            raise ValueError(
                "Production environment does not allow wildcard CORS ('*'). "
                "Specify explicit allowed origins in CORS_ORIGINS."
            )
        return value

    @property
    def cors_origin_list(self) -> list[str]:
        """Return the configured comma-separated origins as a clean list."""
        return [
            origin.strip() for origin in self.cors_origins.split(",") if origin.strip()
        ]


@lru_cache
def get_settings() -> Settings:
    """Return the process-wide cached settings instance."""
    return Settings()
