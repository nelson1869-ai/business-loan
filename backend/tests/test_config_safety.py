"""Backend tests for environment configuration safety and admin router isolation."""

import os
import unittest
from unittest.mock import patch

from pydantic import ValidationError

from app.core.config import Settings


class TestConfigSafety(unittest.TestCase):
    """Test suite for configuration validation and security constraints."""

    def test_valid_development_config(self) -> None:
        """Verify development configuration parses cleanly."""
        settings = Settings(
            app_env="development",
            database_url="postgresql+asyncpg://user:pass@localhost:5432/db",
            jwt_secret_key="strong-random-value-0123456789-ABCDEFGHIJ",
            cors_origins="*",
        )
        self.assertEqual(settings.app_env, "development")
        self.assertEqual(settings.cors_origin_list, ["*"])

    @patch.dict(os.environ, {}, clear=True)
    def test_missing_app_env_fails_closed(self) -> None:
        """Verify APP_ENV is mandatory instead of defaulting to development."""
        with self.assertRaises(ValidationError):
            Settings(
                _env_file=None,
                database_url="postgresql+asyncpg://user:pass@localhost:5432/db",
                jwt_secret_key="strong-random-value-0123456789-ABCDEFGHIJ",
                cors_origins="https://example.test",
            )

    def test_weak_secret_rejected_in_development(self) -> None:
        """Verify placeholder JWT secrets are rejected in every environment."""
        with self.assertRaises(ValidationError):
            Settings(
                app_env="development",
                database_url="postgresql+asyncpg://user:pass@localhost:5432/db",
                jwt_secret_key="0123456789abcdef0123456789abcdef",
                cors_origins="*",
            )

    def test_invalid_app_env_rejected(self) -> None:
        """Verify invalid APP_ENV raises ValidationError."""
        with self.assertRaises(ValidationError):
            Settings(
                app_env="invalid_environment",
                database_url="postgresql+asyncpg://user:pass@localhost:5432/db",
                jwt_secret_key="strong-random-value-0123456789-ABCDEFGHIJ",
            )

    def test_production_weak_secret_rejected(self) -> None:
        """Verify production rejects placeholder or weak JWT secret keys."""
        with self.assertRaises(ValidationError):
            Settings(
                app_env="production",
                database_url="postgresql+asyncpg://user:pass@localhost:5432/db",
                jwt_secret_key="secret",
            )

    def test_production_wildcard_cors_rejected(self) -> None:
        """Verify production rejects wildcard CORS ('*')."""
        with self.assertRaises(ValidationError):
            Settings(
                app_env="production",
                database_url="postgresql+asyncpg://user:pass@localhost:5432/db",
                jwt_secret_key="a_very_strong_random_production_jwt_secret_key_32_bytes",
                cors_origins="*",
            )

    def test_production_explicit_cors_accepted(self) -> None:
        """Verify production accepts explicit comma-separated CORS origins."""
        settings = Settings(
            app_env="production",
            database_url="postgresql+asyncpg://user:pass@localhost:5432/db",
            jwt_secret_key="a_very_strong_random_production_jwt_secret_key_32_bytes",
            cors_origins="https://lending.nelson.com, https://admin.nelson.com",
            n8n_webhook_secret="a_very_strong_n8n_webhook_secret_32_bytes",
        )
        self.assertEqual(
            settings.cors_origin_list,
            ["https://lending.nelson.com", "https://admin.nelson.com"],
        )

    def test_production_unauthenticated_n8n_webhook_rejected(self) -> None:
        """Verify production rejects N8N_WEBHOOK_URL when N8N_WEBHOOK_SECRET is missing."""
        with self.assertRaises(ValidationError):
            Settings(
                app_env="production",
                database_url="postgresql+asyncpg://user:pass@localhost:5432/db",
                jwt_secret_key="a_very_strong_random_production_jwt_secret_key_32_bytes",
                cors_origins="https://lending.nelson.com",
                n8n_webhook_url="https://n8n.example.com/webhook/lending",
                n8n_webhook_secret="",
            )


if __name__ == "__main__":
    unittest.main()
