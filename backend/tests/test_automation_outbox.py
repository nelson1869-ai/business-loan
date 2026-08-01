"""Unit tests for PostgreSQL-backed automation outbox, dispatcher, and manual replay."""

import unittest
import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

from app.features.automation.models import AutomationEventOutbox
from app.features.automation.outbox import (
    publish_outbox_event,
    replay_outbox_event,
)
from app.features.automation.schemas import DomainEventEnvelope, EventActor, EventEntity


class TestAutomationOutbox(unittest.IsolatedAsyncioTestCase):
    async def test_publish_outbox_event_adds_pending_record(self):
        db_session = MagicMock()
        event_id = str(uuid.uuid4())
        envelope = DomainEventEnvelope[dict](
            eventId=event_id,
            eventType="payment.received",
            idempotencyKey=f"payment.received:{event_id}",
            actor=EventActor(id="user-1", role="officer"),
            entity=EventEntity(type="payment", id="pay-10"),
            data={"amount_paid": "2000.00"},
        )

        outbox_rec = await publish_outbox_event(db_session, envelope)

        assert outbox_rec.event_id == event_id
        assert outbox_rec.status == "pending"
        assert outbox_rec.attempt_count == 0
        db_session.add.assert_called_once_with(outbox_rec)

    async def test_replay_outbox_event_resets_dead_lettered_status(self):
        event_id = str(uuid.uuid4())
        now = datetime.now(timezone.utc)
        failed_record = AutomationEventOutbox(
            event_id=event_id,
            event_type="installment.overdue",
            payload={"loan_id": "l-1"},
            status="dead_lettered",
            attempt_count=8,
            last_error="HTTP 500 Connection Refused",
            created_at=now,
            updated_at=now,
            correlation_id=str(uuid.uuid4()),
            idempotency_key=f"installment.overdue:{event_id}",
        )

        db_session = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = failed_record
        db_session.execute.return_value = mock_result

        replayed = await replay_outbox_event(db_session, event_id)
        assert replayed is not None
        assert replayed.status == "pending"
        assert replayed.attempt_count == 0
        assert replayed.last_error is None
        assert replayed.event_id == event_id


if __name__ == "__main__":
    unittest.main()
