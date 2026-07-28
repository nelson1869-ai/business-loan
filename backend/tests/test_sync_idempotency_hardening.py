"""Tests for backend offline sync idempotency, receipt creation, and allowlist validation."""

import pytest
from unittest.mock import AsyncMock, MagicMock
from app.routers.sync import SyncQueueItem, _replay_item, SyncReplayError


@pytest.mark.asyncio
async def test_replay_item_unsupported_endpoint_raises_replay_error():
    """Verify that unsupported endpoints raise an UNSUPPORTED_ENDPOINT error."""
    item = SyncQueueItem(
        transaction_uuid="11111111-1111-1111-1111-111111111111",
        endpoint="/api/v1/borrowers/22222222-2222-2222-2222-222222222222",
        method="POST", # Invalid: POST to single borrower endpoint is not supported
        payload={"id": "22222222-2222-2222-2222-222222222222", "full_name": "Test Borrower"},
        created_at="2026-07-28T12:00:00Z",
    )
    db = AsyncMock()
    user = MagicMock()
    user.id = "33333333-3333-3333-3333-333333333333"

    with pytest.raises(SyncReplayError) as exc_info:
        await _replay_item(item, db, user)

    assert exc_info.value.code == "UNSUPPORTED_ENDPOINT"
    assert exc_info.value.retryable is False


@pytest.mark.asyncio
async def test_replay_item_loan_missing_request_id_raises_invalid_payload():
    """Verify offline loan creation missing requestId raises INVALID_PAYLOAD."""
    item = SyncQueueItem(
        transaction_uuid="44444444-4444-4444-4444-444444444444",
        endpoint="/api/v1/loans",
        method="POST",
        payload={
            "borrower_id": "55555555-5555-5555-5555-555555555555",
            "original_principal": "1000.00",
            "monthly_rate": "0.05",
            "term_months": 3,
            "payments_per_month": 1,
            "start_date": "2026-08-01",
            "first_due_date": "2026-09-01",
        },
        created_at="2026-07-28T12:00:00Z",
    )
    db = AsyncMock()
    user = MagicMock()
    user.id = "33333333-3333-3333-3333-333333333333"

    with pytest.raises(SyncReplayError) as exc_info:
        await _replay_item(item, db, user)

    assert exc_info.value.code == "INVALID_PAYLOAD"
    assert exc_info.value.retryable is False
