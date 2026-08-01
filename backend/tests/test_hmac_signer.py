"""Unit tests for HMAC-SHA256 signature generation, verification, and timestamp security."""

import time

import pytest

from app.features.automation.hmac import generate_hmac_signature, verify_hmac_signature


def test_hmac_signature_generation_and_verification():
    secret = "test-super-secret-hmac-key-32chars"
    timestamp = str(int(time.time()))
    body = b'{"eventId":"ev-1","eventType":"payment.received"}'

    signature = generate_hmac_signature(secret, timestamp, body)
    assert signature.startswith("sha256=")

    is_valid, reason = verify_hmac_signature(
        secret=secret,
        timestamp_str=timestamp,
        raw_body=body,
        signature_header=signature,
        max_age_seconds=300,
    )
    assert is_valid is True
    assert reason == ""


def test_hmac_verification_fails_on_tampered_body():
    secret = "test-super-secret-hmac-key-32chars"
    timestamp = str(int(time.time()))
    body = b'{"eventId":"ev-1","amount":"1000.00"}'
    tampered_body = b'{"eventId":"ev-1","amount":"9999.00"}'

    signature = generate_hmac_signature(secret, timestamp, body)

    is_valid, reason = verify_hmac_signature(
        secret=secret,
        timestamp_str=timestamp,
        raw_body=tampered_body,
        signature_header=signature,
        max_age_seconds=300,
    )
    assert is_valid is False
    assert "Signature mismatch" in reason


def test_hmac_verification_fails_on_expired_timestamp():
    secret = "test-super-secret-hmac-key-32chars"
    expired_timestamp = str(int(time.time()) - 600)  # 10 minutes old
    body = b'{"eventId":"ev-1"}'

    signature = generate_hmac_signature(secret, expired_timestamp, body)

    is_valid, reason = verify_hmac_signature(
        secret=secret,
        timestamp_str=expired_timestamp,
        raw_body=body,
        signature_header=signature,
        max_age_seconds=300,
    )
    assert is_valid is False
    assert "Timestamp expired" in reason


def test_empty_secret_raises_exception():
    with pytest.raises(ValueError, match="HMAC secret cannot be empty"):
        generate_hmac_signature("", "1234567890", b"test")
