"""Environment-backed application configuration."""

from functools import lru_cache

from pydantic import Field, SecretStr, ValidationInfo, field_validator, model_validator
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
    n8n_enabled: bool = False
    n8n_webhook_url: str | None = None
    n8n_webhook_secret: str | None = None
    n8n_timeout_seconds: float = Field(default=5.0, gt=0, le=60)
    n8n_max_attempts: int = Field(default=8, ge=1, le=20)
    n8n_retry_base_seconds: int = Field(default=30, ge=1, le=3600)
    n8n_signature_max_age_seconds: int = Field(default=300, ge=30, le=3600)
    n8n_service_api_key: str | None = None
    nvidia_api_key: SecretStr | None = None
    nvidia_base_url: str | None = None
    ai_enabled: bool = True
    ai_provider: str = "nvidia"
    ai_model: str = "openai/gpt-oss-20b"
    ai_explanations_enabled: bool = True
    ai_timeout_seconds: float = Field(default=20.0, gt=0, le=120)
    ai_max_output_tokens: int = Field(default=160, ge=64, le=300)
    ai_temperature: float = Field(default=0.2, ge=0, le=1)
    ai_max_retries: int = Field(default=0, ge=0, le=1)
    ai_cache_ttl_seconds: int = Field(default=300, ge=0, le=3600)
    ai_failure_cooldown_seconds: int = Field(default=120, ge=0, le=3600)
    assistant_rate_limit_per_minute: int = Field(default=30, ge=5, le=300)
    assistant_rate_limit_redis_url: str | None = None
    login_rate_limit_per_minute: int = Field(default=5, ge=1, le=100)
    business_timezone: str = "Asia/Manila"
    currency_code: str = Field(default="PHP", min_length=3, max_length=3)

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
    def validate_jwt_secret_key(cls, value: str, info: ValidationInfo) -> str:
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
    def validate_cors_origins(cls, value: str, info: ValidationInfo) -> str:
        """Reject wildcard CORS in production environments."""
        env = info.data.get("app_env", "").lower().strip()
        if env in ("production", "prod") and value.strip() == "*":
            raise ValueError(
                "Production environment does not allow wildcard CORS ('*'). "
                "Specify explicit allowed origins in CORS_ORIGINS."
            )
        return value

    @field_validator("n8n_webhook_secret")
    @classmethod
    def validate_n8n_webhook_secret(
        cls, value: str | None, info: ValidationInfo
    ) -> str | None:
        """Enforce that n8n webhook authentication fails closed in production and staging."""
        env = info.data.get("app_env", "").lower().strip()
        webhook_url = info.data.get("n8n_webhook_url")
        if env in ("production", "prod", "staging") and webhook_url and not value:
            raise ValueError(
                "N8N_WEBHOOK_SECRET must be configured when N8N_WEBHOOK_URL is set in production/staging."
            )
        return value

    @property
    def cors_origin_list(self) -> list[str]:
        """Return the configured comma-separated origins as a clean list."""
        return [
            origin.strip() for origin in self.cors_origins.split(",") if origin.strip()
        ]

    @property
    def ai_explanations_available(self) -> bool:
        """Return whether the optional AI explanation integration is configured."""
        return (
            self.ai_explanations_enabled
            and self.ai_enabled
            and self.ai_provider.lower() == "nvidia"
            and self.nvidia_api_key is not None
            and bool(self.nvidia_api_key.get_secret_value().strip())
            and self.nvidia_base_url is not None
            and bool(self.nvidia_base_url.strip())
        )

    @field_validator("currency_code")
    @classmethod
    def normalize_currency_code(cls, value: str) -> str:
        """Store an ISO-style uppercase currency code."""
        return value.upper()




@lru_cache
def get_settings() -> Settings:
    """Return the process-wide cached settings instance."""
    return Settings()
