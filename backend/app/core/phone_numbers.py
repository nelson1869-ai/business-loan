"""Canonical phone-number handling shared by borrower features."""

import re


def normalize_ph_phone_number(raw_phone: str) -> str:
    """Normalize a Philippine mobile number to ``+639XXXXXXXXX``."""
    cleaned = re.sub(r"[\s\-\(\)\+]", "", raw_phone)
    if cleaned.startswith("09") and len(cleaned) == 11:
        return "+63" + cleaned[1:]
    if cleaned.startswith("639") and len(cleaned) == 12:
        return "+" + cleaned
    if cleaned.startswith("9") and len(cleaned) == 10:
        return "+63" + cleaned
    if cleaned.startswith("6309") and len(cleaned) == 13:
        return "+63" + cleaned[3:]
    raise ValueError("Invalid Philippine mobile number format")
