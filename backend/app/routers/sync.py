"""Ordered offline mutation replay routes."""

from fastapi import APIRouter
from pydantic import ValidationError
from sqlalchemy.exc import IntegrityError

from app.dependencies import CurrentUser, DbSession
from app.schemas.borrower import BorrowerCreate, BorrowerUpdate
from app.schemas.sync import (
    SyncBatchRequest,
    SyncBatchResponse,
    SyncFailure,
    SyncQueueItem,
)
from app.services import borrower_service

router = APIRouter(prefix="/api/v1/sync", tags=["Offline Sync"])


async def _replay_item(
    item: SyncQueueItem,
    db: DbSession,
    current_user: CurrentUser,
) -> None:
    """Replay one validated borrower mutation without committing it."""
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
