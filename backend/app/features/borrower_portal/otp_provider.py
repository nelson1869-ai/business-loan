"""OTP Provider interface and safe development / production handlers."""

import logging
from abc import ABC, abstractmethod

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


class SmsGatewayOTPProvider(BaseOTPProvider):
    """Production SMS Gateway placeholder (e.g. Semaphore / Twilio integration)."""

    async def send_otp(self, phone_number_normalized: str, otp: str) -> bool:
        """Dispatch OTP via production SMS API credentials."""
        # Production gateway payload logic goes here
        logger.info(
            "Dispatched production SMS OTP to %s", phone_number_normalized[:6] + "..."
        )
        return True
