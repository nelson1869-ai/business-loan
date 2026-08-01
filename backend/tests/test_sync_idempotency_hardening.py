"""Tests for backend offline sync idempotency and allowlist validation."""

from unittest.mock import AsyncMock, MagicMock

import pytest

from app.features.sync.models import SyncReceipt
from app.features.sync.router import (
    SyncReplayError,
    _replay_item,
    drain_sync_queue,
)
from app.features.sync.schemas import SyncBatchRequest, SyncQueueItem


@pytest.mark.asyncio
async def test_replay_item_unsupported_endpoint_raises_replay_error():
    """Verify that unsupported endpoints raise an UNSUPPORTED_ENDPOINT error."""
    item = SyncQueueItem(
        transaction_uuid="11111111-1111-1111-1111-111111111111",
        endpoint="/api/v1/borrowers/22222222-2222-2222-2222-222222222222",
        method="POST",  # Invalid: POST to a single borrower is unsupported.
        payload={
            "id": "22222222-2222-2222-2222-222222222222",
            "full_name": "Synthetic Fixture",
        },
        created_at="2026-07-28T12:00:00Z",
    )
    db = AsyncMock()
    user = MagicMock()
    user.id = "33333333-3333-3333-3333-333333333333"

    with pytest.raises(SyncReplayError) as exc_info:
        await _replay_item(item, db, user)

    assert exc_info.value.code == "UNSUPPORTED_ENDPOINT"
    assert exc_info.value.retryable is False


def test_sync_batch_rejects_duplicate_transaction_uuids():
    """A batch cannot replay one idempotency key twice."""
    item = {
        "transactionUuid": "11111111-1111-1111-1111-111111111111",
        "endpoint": "/api/v1/borrowers",
        "method": "POST",
        "payload": {},
        "createdAt": "2026-07-28T12:00:00Z",
    }
    with pytest.raises(ValueError):
        SyncBatchRequest.model_validate({"items": [item, item]})


@pytest.mark.asyncio
async def test_receipt_owner_mismatch_is_rejected_without_replay():
    """An authenticated actor cannot consume another actor's receipt."""
    item = SyncQueueItem(
        transaction_uuid="11111111-1111-1111-1111-111111111111",
        endpoint="/api/v1/borrowers",
        method="POST",
        payload={},
        created_at="2026-07-28T12:00:00Z",
    )
    receipt = SyncReceipt(
        transaction_uuid=item.transaction_uuid,
        user_id="22222222-2222-2222-2222-222222222222",
    )
    db = AsyncMock()
    db.get.return_value = receipt
    user = MagicMock(id="33333333-3333-3333-3333-333333333333")

    result = await drain_sync_queue(
        SyncBatchRequest(items=[item]),
        db,
        user,
    )

    assert result.synced_transaction_uuids == []
    assert result.failures[0].code == "IDEMPOTENCY_CONFLICT"
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_receipt_and_mutation_share_one_commit(monkeypatch):
    """A failed commit rolls back both replay work and its receipt."""
    item = SyncQueueItem(
        transaction_uuid="11111111-1111-1111-1111-111111111111",
        endpoint="/api/v1/borrowers",
        method="POST",
        payload={},
        created_at="2026-07-28T12:00:00Z",
    )
    replay = AsyncMock()
    monkeypatch.setattr("app.features.sync.router._replay_item", replay)
    db = AsyncMock()
    db.add = MagicMock()
    db.get.return_value = None
    db.commit.side_effect = RuntimeError("synthetic commit failure")
    user = MagicMock(id="33333333-3333-3333-3333-333333333333")

    result = await drain_sync_queue(
        SyncBatchRequest(items=[item]),
        db,
        user,
    )

    replay.assert_awaited_once()
    receipt = db.add.call_args.args[0]
    assert isinstance(receipt, SyncReceipt)
    assert receipt.user_id == user.id
    db.rollback.assert_awaited_once()
    assert result.synced_transaction_uuids == []
    assert result.failures[0].retryable is True


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
