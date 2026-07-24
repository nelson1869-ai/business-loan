"""Backend tests for environment configuration safety and admin router isolation."""

import os
import unittest
from unittest.mock import patch

from pydantic import ValidationError

from app.config import Settings


class TestConfigSafety(unittest.TestCase):
    """Test suite for configuration validation and security constraints."""

    def test_valid_development_config(self) -> None:
        """Verify development configuration parses cleanly."""
        settings = Settings(
            app_env="development",
            database_url="postgresql+asyncpg://user:pass@localhost:5432/db",
            jwt_secret_key="0123456789abcdef0123456789abcdef",
            cors_origins="*",
        )
        self.assertEqual(settings.app_env, "development")
        self.assertEqual(settings.cors_origin_list, ["*"])

    def test_invalid_app_env_rejected(self) -> None:
        """Verify invalid APP_ENV raises ValidationError."""
        with self.assertRaises(ValidationError):
            Settings(
                app_env="invalid_environment",
                database_url="postgresql+asyncpg://user:pass@localhost:5432/db",
                jwt_secret_key="0123456789abcdef0123456789abcdef",
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
        )
        self.assertEqual(
            settings.cors_origin_list,
            ["https://lending.nelson.com", "https://admin.nelson.com"],
        )

    @patch.dict(
        os.environ,
        {
            "APP_ENV": "production",
            "CORS_ORIGINS": "https://lending.nelson.com",
            "JWT_SECRET_KEY": "a_very_strong_random_production_jwt_secret_key_32_bytes",
        },
    )
    def test_admin_routes_disabled_in_production(self) -> None:
        """Verify admin routes are excluded from OpenAPI schema when APP_ENV=production."""
        from app.config import get_settings
        get_settings.cache_clear()

        from app.main import create_app
        prod_app = create_app()
        paths = prod_app.openapi()["paths"]

        self.assertNotIn("/api/v1/admin/reset", paths)
        self.assertNotIn("/api/v1/admin/seed", paths)

        get_settings.cache_clear()


if __name__ == "__main__":
    unittest.main()
