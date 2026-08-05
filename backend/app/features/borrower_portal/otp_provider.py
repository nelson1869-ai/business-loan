"""OTP Provider interface and safe development / production handlers."""

import logging
from abc import ABC, abstractmethod

import httpx

from app.core.config import Settings, get_settings

logger = logging.getLogger(__name__)


def _mask_phone(phone_number: str) -> str:
    """Return a safely masked phone number for logs."""
    if len(phone_number) <= 6:
        return "***"
    return f"{phone_number[:6]}..."


class BaseOTPProvider(ABC):
    """Abstract interface for OTP delivery providers."""

    @abstractmethod
    async def send_otp(self, phone_number_normalized: str, otp: str) -> bool:
        """Deliver OTP to the target phone number."""


class DevelopmentOTPProvider(BaseOTPProvider):
    """Development OTP provider for local testing only."""

    def __init__(self, is_development: bool = True) -> None:
        self.is_development = is_development
        self.last_delivered_otp: dict[str, str] = {}

    async def send_otp(self, phone_number_normalized: str, otp: str) -> bool:
        """Store OTP for development test inspection."""
        if self.is_development:
            self.last_delivered_otp[phone_number_normalized] = otp
            logger.info(
                "Development OTP generated for %s",
                _mask_phone(phone_number_normalized),
            )

        return True


class AndroidSmsGatewayOTPProvider(BaseOTPProvider):
    """Dispatch OTP through the SMSGate public cloud API."""

    def __init__(
        self,
        gateway_url: str,
        username: str | None = None,
        password: str | None = None,
    ) -> None:
        self.gateway_url = gateway_url.rstrip("/")
        self.username = username.strip() if username else None
        self.password = password.strip() if password else None

    async def send_otp(self, phone_number_normalized: str, otp: str) -> bool:
        """Send an OTP through SMSGate using HTTP Basic Authentication."""
        masked_phone = _mask_phone(phone_number_normalized)

        if not self.username or not self.password:
            logger.error(
                "SMSGate credentials are missing for recipient %s",
                masked_phone,
            )
            return False

        message_text = f"Your Lending Nelson verification code is: {otp}"

        payload = {
            "textMessage": {
                "text": message_text,
            },
            "phoneNumbers": [
                phone_number_normalized,
            ],
        }

        timeout = httpx.Timeout(
            connect=10.0,
            read=20.0,
            write=10.0,
            pool=10.0,
        )

        auth = httpx.BasicAuth(
            username=self.username,
            password=self.password,
        )

        try:
            async with httpx.AsyncClient(timeout=timeout) as client:
                response = await client.post(
                    self.gateway_url,
                    json=payload,
                    auth=auth,
                    headers={
                        "Accept": "application/json",
                        "Content-Type": "application/json",
                    },
                )

            if response.status_code in (200, 201, 202):
                logger.info(
                    "SMSGate accepted OTP message for %s with HTTP %s",
                    masked_phone,
                    response.status_code,
                )
                return True

            if response.status_code in (401, 403):
                logger.error(
                    "SMSGate authentication failed with HTTP %s for %s",
                    response.status_code,
                    masked_phone,
                )
                return False

            if response.status_code == 404:
                logger.error(
                    "SMSGate endpoint was not found for %s",
                    masked_phone,
                )
                return False

            if response.status_code == 422:
                logger.error(
                    "SMSGate rejected the request payload for %s",
                    masked_phone,
                )
                return False

            logger.warning(
                "SMSGate returned HTTP %s for %s",
                response.status_code,
                masked_phone,
            )
            return False

        except httpx.ConnectTimeout:
            logger.error(
                "Timed out connecting to SMSGate for %s",
                masked_phone,
            )
            return False

        except httpx.ReadTimeout:
            logger.error(
                "Timed out waiting for SMSGate response for %s",
                masked_phone,
            )
            return False

        except httpx.ConnectError as exc:
            logger.error(
                "Could not connect to SMSGate for %s: %s",
                masked_phone,
                type(exc).__name__,
            )
            return False

        except httpx.HTTPError as exc:
            logger.error(
                "SMSGate HTTP error for %s: %s",
                masked_phone,
                type(exc).__name__,
            )
            return False

        except Exception as exc:
            logger.exception(
                "Unexpected SMSGate error for %s: %s",
                masked_phone,
                type(exc).__name__,
            )
            return False


class SmsGatewayOTPProvider(BaseOTPProvider):
    """Placeholder for another production SMS provider."""

    async def send_otp(self, phone_number_normalized: str, otp: str) -> bool:
        """Dispatch OTP using another configured production provider."""
        logger.warning(
            "Generic production SMS provider is not implemented for %s",
            _mask_phone(phone_number_normalized),
        )
        return False


dev_otp_provider = DevelopmentOTPProvider(is_development=True)


def get_otp_provider(settings: Settings | None = None) -> BaseOTPProvider:
    """Return the OTP provider configured through environment variables."""
    cfg = settings or get_settings()
    provider_type = (cfg.sms_gateway_provider or "dev").lower().strip()

    if provider_type == "android_gateway":
        if not cfg.android_sms_gateway_url:
            logger.error("ANDROID_SMS_GATEWAY_URL is not configured")
            return SmsGatewayOTPProvider()

        if not cfg.android_sms_gateway_user:
            logger.error("ANDROID_SMS_GATEWAY_USER is not configured")
            return SmsGatewayOTPProvider()

        if not cfg.android_sms_gateway_key:
            logger.error("ANDROID_SMS_GATEWAY_KEY is not configured")
            return SmsGatewayOTPProvider()

        return AndroidSmsGatewayOTPProvider(
            gateway_url=cfg.android_sms_gateway_url,
            username=cfg.android_sms_gateway_user,
            password=cfg.android_sms_gateway_key,
        )

    if provider_type == "dev" or cfg.app_env.lower() in ("test", "testing"):
        return dev_otp_provider

    logger.error("Unsupported SMS gateway provider: %s", provider_type)
    return SmsGatewayOTPProvider()