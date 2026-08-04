"""OTP Provider interface and safe development / production handlers."""

import logging
from abc import ABC, abstractmethod

import httpx

from app.core.config import Settings, get_settings

logger = logging.getLogger(__name__)


class BaseOTPProvider(ABC):
    """Abstract interface for OTP delivery providers."""

    @abstractmethod
    async def send_otp(self, phone_number_normalized: str, otp: str) -> bool:
        """Deliver OTP to the target phone number."""


class DevelopmentOTPProvider(BaseOTPProvider):
    """Development OTP provider that logs OTP internally without exposing it to client responses."""

    def __init__(self, is_development: bool = True) -> None:
        self.is_development = is_development
        self.last_delivered_otp: dict[str, str] = {}

    async def send_otp(self, phone_number_normalized: str, otp: str) -> bool:
        """Store OTP for dev test inspection; never log sensitive data in production."""
        if self.is_development:
            self.last_delivered_otp[phone_number_normalized] = otp
            logger.info(
                "Dev OTP generated for %s (redacted in prod)",
                phone_number_normalized[:6] + "...",
            )
        return True


class AndroidSmsGatewayOTPProvider(BaseOTPProvider):
    """Dispatches OTP via Android Phone SMS Gateway API (₱0 SMS cost)."""

    def __init__(self, gateway_url: str, api_key: str | None = None) -> None:
        self.gateway_url = gateway_url.rstrip("/")
        self.api_key = api_key

    async def send_otp(self, phone_number_normalized: str, otp: str) -> bool:
        """Send HTTP request to Android Gateway app on mobile device to trigger real SMS."""
        message_text = f"Your Lending Nelson verification code is: {otp}"
        payload = {
            "phoneNumbers": [phone_number_normalized],
            "phone": phone_number_normalized,
            "to": phone_number_normalized,
            "message": message_text,
        }
        headers = {"Content-Type": "application/json"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
            headers["X-API-Key"] = self.api_key

        try:
            async with httpx.AsyncClient(timeout=4.0) as client:
                response = await client.post(self.gateway_url, json=payload, headers=headers)
                if response.status_code in (200, 201, 202):
                    logger.info(
                        "Dispatched Android SMS Gateway OTP to %s",
                        phone_number_normalized[:6] + "...",
                    )
                    return True
                logger.warning(
                    "Android SMS Gateway returned HTTP %s for %s",
                    response.status_code,
                    phone_number_normalized[:6] + "...",
                )
                return False
        except Exception as exc:
            logger.error("Failed to connect to Android SMS Gateway: %s", exc)
            return False


class SmsGatewayOTPProvider(BaseOTPProvider):
    """Production SMS Gateway placeholder (e.g. Semaphore / Twilio integration)."""

    async def send_otp(self, phone_number_normalized: str, otp: str) -> bool:
        """Dispatch OTP via production SMS API credentials."""
        logger.info(
            "Dispatched production SMS OTP to %s", phone_number_normalized[:6] + "..."
        )
        return True


dev_otp_provider = DevelopmentOTPProvider(is_development=True)


def get_otp_provider(settings: Settings | None = None) -> BaseOTPProvider:
    """Factory function returning configured OTP provider."""
    cfg = settings or get_settings()
    provider_type = (cfg.sms_gateway_provider or "dev").lower().strip()
    if provider_type == "android_gateway" and cfg.android_sms_gateway_url:
        return AndroidSmsGatewayOTPProvider(
            gateway_url=cfg.android_sms_gateway_url,
            api_key=cfg.android_sms_gateway_key,
        )
    return dev_otp_provider


