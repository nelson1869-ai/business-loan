"""Unit tests for versioned backend-to-n8n event envelope and Pydantic domain schemas."""

import json

from app.features.automation.schemas import (
    DomainEventEnvelope,
    EventActor,
    EventEntity,
    PaymentReceivedData,
)


def test_domain_event_envelope_defaults():
    """Verify default envelope metadata fields."""
    envelope = DomainEventEnvelope[PaymentReceivedData](
        eventType="payment.received",
        idempotencyKey="payment.received:pay-001",
        actor=EventActor(id="user-001", role="officer"),
        entity=EventEntity(type="payment", id="pay-001"),
        data=PaymentReceivedData(
            payment_id="pay-001",
            loan_id="loan-001",
            borrower_id="bor-001",
            amount_paid="1500.00",
            remaining_balance="8500.00",
            effective_date="2026-07-31",
            borrower_phone="+639000000000",
        ),
    )

    assert envelope.eventVersion == 1
    assert envelope.businessTimezone == "Asia/Manila"
    assert envelope.source == "lending-nelson-api"
    assert len(envelope.eventId) == 36
    assert len(envelope.correlationId) == 36
    assert envelope.actor.id == "user-001"
    assert envelope.entity.id == "pay-001"
    assert envelope.data.amount_paid == "1500.00"

    dumped = envelope.model_dump(mode="json")
    assert dumped["businessTimezone"] == "Asia/Manila"
    assert dumped["idempotencyKey"] == "payment.received:pay-001"


def test_domain_event_envelope_json_serialization():
    """Verify clean JSON serialization without custom encoder errors."""
    envelope = DomainEventEnvelope[dict](
        eventType="loan.created",
        idempotencyKey="loan.created:loan-100",
        actor=EventActor(id="officer-1", role="officer"),
        entity=EventEntity(type="loan", id="loan-100"),
        data={"loan_id": "loan-100", "principal": "50000.00"},
    )
    raw_json = envelope.model_dump_json()
    parsed = json.loads(raw_json)
    assert parsed["eventType"] == "loan.created"
    assert parsed["data"]["principal"] == "50000.00"
