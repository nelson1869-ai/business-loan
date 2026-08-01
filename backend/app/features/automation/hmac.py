"""HMAC-SHA256 signature generator and verification service."""

import hashlib
import hmac
import time
from typing import Tuple


def generate_hmac_signature(secret: str, timestamp: str, raw_body: bytes) -> str:
    """Generate SHA256 HMAC signature for a request payload.

    Signature pattern: HMAC-SHA256(secret, timestamp + "." + raw_body)
    """
    if not secret:
        raise ValueError("HMAC secret cannot be empty.")

    signed_payload = timestamp.encode("utf-8") + b"." + raw_body
    signature = hmac.new(
        secret.encode("utf-8"),
        signed_payload,
        hashlib.sha256,
    ).hexdigest()
    return f"sha256={signature}"


def verify_hmac_signature(
    secret: str,
    timestamp_str: str,
    raw_body: bytes,
    signature_header: str,
    max_age_seconds: int = 300,
) -> Tuple[bool, str]:
    """Verify HMAC signature and timestamp freshness using constant-time comparison.

    Returns (is_valid, error_reason).
    """
    if not secret:
        return False, "Server secret not configured"

    if not timestamp_str or not signature_header:
        return False, "Missing required security headers"

    try:
        timestamp = int(timestamp_str)
    except ValueError:
        return False, "Invalid timestamp header format"

    now = int(time.time())
    if abs(now - timestamp) > max_age_seconds:
        return False, f"Timestamp expired or in future (skew > {max_age_seconds}s)"

    expected_signature = generate_hmac_signature(secret, timestamp_str, raw_body)

    if hmac.compare_digest(expected_signature, signature_header):
        return True, ""

    # Also support signature header without 'sha256=' prefix if provided
    raw_expected = expected_signature.replace("sha256=", "")
    raw_provided = signature_header.replace("sha256=", "")
    if hmac.compare_digest(raw_expected, raw_provided):
        return True, ""

    return False, "Signature mismatch"
