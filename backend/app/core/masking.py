"""Centralized data masking utilities for PII protection."""

__all__ = ["mask_phone", "mask_national_id"]


def mask_phone(phone: str) -> str:
    """Mask phone numbers for display/logs while keeping leading and trailing digits visible."""
    return f"{phone[:3]}•••••{phone[-3:]}" if len(phone) >= 7 else "••••"


def mask_national_id(national_id: str | None) -> str:
    """Mask national identity document numbers for security display."""
    if not national_id:
        return "Not provided"
    return f"{'•' * max(4, len(national_id) - 4)}{national_id[-4:]}"
