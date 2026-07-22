"""Ordered offline mutation replay routes."""

from fastapi import APIRouter
from pydantic import ValidationError
from sqlalchemy.exc import IntegrityError

from app.dependencies import CurrentUser, DbSession
from app.schemas.borrower import BorrowerCreate, BorrowerUpdate
from app.schemas.loan import LoanCreate
from app.schemas.payment import PaymentCreate, PaymentReversalCreate
from app.schemas.sync import (
    SyncBatchRequest,
    SyncBatchResponse,
    SyncFailure,
    SyncQueueItem,
)
from app.services import borrower_service, loan_service, payment_service

router = APIRouter(prefix="/api/v1/sync", tags=["Offline Sync"])


async def _replay_item(
    item: SyncQueueItem,
    db: DbSession,
    current_user: CurrentUser,
) -> None:
    """Replay one validated mutation without committing it."""
    if item.endpoint == "/api/v1/loans" and item.method == "POST":
        payload = LoanCreate.model_validate(item.payload)
        if payload.request_id is None:
            raise ValueError("Offline loan creation requires requestId")
        existing = await loan_service.get_loan_by_request_id(db, payload.request_id)
        if existing is not None:
            if not loan_service.loan_matches_request(existing, payload, current_user.id):
                raise ValueError("Loan request ID conflicts with existing data")
            return
        if await borrower_service.get_borrower(db, payload.borrower_id) is None:
            raise ValueError("Borrower not found")
        await loan_service.create_loan(db, payload, current_user)
        return

    if "/payments" in item.endpoint and item.method == "POST":
        parts = item.endpoint.split("/")
        loan_id = parts[4]
        if item.endpoint.endswith("/reversal"):
            payment_id = parts[6]
            payload = PaymentReversalCreate.model_validate(item.payload)
            existing = await payment_service.get_payment_by_request_id(db, payload.request_id)
            if existing is not None:
                if not payment_service.reversal_matches_request(existing, loan_id, payment_id, payload):
                    raise ValueError("Reversal request ID conflicts with existing data")
                return
            await payment_service.reverse_latest_payment(db, loan_id, payment_id, payload, current_user)
            return
        payload = PaymentCreate.model_validate(item.payload)
        existing = await payment_service.get_payment_by_request_id(db, payload.request_id)
        if existing is not None:
            if not payment_service.payment_matches_request(existing, loan_id, payload):
                raise ValueError("Payment request ID conflicts with existing data")
            return
        await payment_service.record_payment(db, loan_id, payload, current_user)
        return

    borrower_id = item.endpoint.rsplit("/", maxsplit=1)[-1]
    if item.method == "POST":
        payload = BorrowerCreate.model_validate(item.payload)
        existing = await borrower_service.get_borrower(db, payload.id)
        if existing is None:
            await borrower_service.create_borrower(db, payload, current_user)
        return

    borrower = await borrower_service.get_borrower(db, borrower_id)
    if item.method == "DELETE":
        if borrower is not None:
            await borrower_service.delete_borrower(db, borrower, current_user)
        return

    if borrower is None:
        raise ValueError("Borrower not found")
    payload = BorrowerUpdate.model_validate(item.payload)
    await borrower_service.update_borrower(db, borrower, payload, current_user)


@router.post("/drain", response_model=SyncBatchResponse)
async def drain_sync_queue(
    payload: SyncBatchRequest,
    db: DbSession,
    current_user: CurrentUser,
) -> SyncBatchResponse:
    """Replay offline mutations in order and report per-item outcomes."""
    synced: list[str] = []
    failures: list[SyncFailure] = []
    for item in sorted(payload.items, key=lambda queued: queued.created_at):
        try:
            await _replay_item(item, db, current_user)
            await db.commit()
            synced.append(item.transaction_uuid)
        except IntegrityError:
            await db.rollback()
            failures.append(
                SyncFailure(
                    transaction_uuid=item.transaction_uuid,
                    detail="Mutation conflicts with existing data",
                )
            )
        except (ValidationError, ValueError):
            await db.rollback()
            failures.append(
                SyncFailure(
                    transaction_uuid=item.transaction_uuid,
                    detail="Mutation payload is invalid",
                )
            )
    return SyncBatchResponse(synced_transaction_uuids=synced, failures=failures)
