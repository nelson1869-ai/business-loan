"""Ordered offline mutation replay routes."""

from fastapi import APIRouter
from pydantic import ValidationError
from sqlalchemy.exc import DBAPIError, IntegrityError

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


class SyncReplayError(Exception):
    """Specific error during replay with code and retryability metadata."""

    def __init__(self, code: str, detail: str, retryable: bool = False) -> None:
        super().__init__(detail)
        self.code = code
        self.detail = detail
        self.retryable = retryable


async def _replay_item(
    item: SyncQueueItem,
    db: DbSession,
    current_user: CurrentUser,
) -> None:
    """Replay one validated mutation without committing it."""
    if item.endpoint == "/api/v1/loans" and item.method == "POST":
        payload = LoanCreate.model_validate(item.payload)
        if payload.request_id is None:
            raise SyncReplayError(
                "INVALID_PAYLOAD",
                "Offline loan creation requires requestId",
                retryable=False,
            )
        existing = await loan_service.get_loan_by_request_id(db, payload.request_id)
        if existing is not None:
            if not loan_service.loan_matches_request(
                existing, payload, current_user.id
            ):
                raise SyncReplayError(
                    "IDEMPOTENCY_CONFLICT",
                    "Loan request ID conflicts with existing data",
                    retryable=False,
                )
            return
        if await borrower_service.get_borrower(db, payload.borrower_id) is None:
            raise SyncReplayError(
                "RESOURCE_NOT_FOUND",
                "Borrower for loan does not exist",
                retryable=False,
            )
        await loan_service.create_loan(db, payload, current_user)
        return

    if "/payments" in item.endpoint and item.method == "POST":
        parts = item.endpoint.split("/")
        loan_id = parts[4]
        if item.endpoint.endswith("/reversal"):
            payment_id = parts[6]
            payload = PaymentReversalCreate.model_validate(item.payload)
            existing = await payment_service.get_payment_by_request_id(
                db, payload.request_id
            )
            if existing is not None:
                if not payment_service.reversal_matches_request(
                    existing, loan_id, payment_id, payload
                ):
                    raise SyncReplayError(
                        "IDEMPOTENCY_CONFLICT",
                        "Reversal request ID conflicts with existing data",
                        retryable=False,
                    )
                return
            await payment_service.reverse_latest_payment(
                db, loan_id, payment_id, payload, current_user
            )
            return
        payload = PaymentCreate.model_validate(item.payload)
        existing = await payment_service.get_payment_by_request_id(
            db, payload.request_id
        )
        if existing is not None:
            if not payment_service.payment_matches_request(existing, loan_id, payload):
                raise SyncReplayError(
                    "IDEMPOTENCY_CONFLICT",
                    "Payment request ID conflicts with existing data",
                    retryable=False,
                )
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
            try:
                await borrower_service.delete_borrower(db, borrower, current_user)
            except borrower_service.BorrowerHasOpenLoansError as error:
                raise SyncReplayError(
                    "INVALID_WORKFLOW_STATE",
                    str(error),
                    retryable=False,
                ) from error
        return

    if borrower is None:
        raise SyncReplayError(
            "RESOURCE_NOT_FOUND", "Borrower does not exist", retryable=False
        )
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
        except SyncReplayError as error:
            await db.rollback()
            failures.append(
                SyncFailure(
                    transaction_uuid=item.transaction_uuid,
                    code=error.code,
                    detail=error.detail,
                    retryable=error.retryable,
                )
            )
        except IntegrityError:
            await db.rollback()
            failures.append(
                SyncFailure(
                    transaction_uuid=item.transaction_uuid,
                    code="IDEMPOTENCY_CONFLICT",
                    detail="Mutation conflicts with existing data",
                    retryable=False,
                )
            )
        except ValidationError:
            await db.rollback()
            failures.append(
                SyncFailure(
                    transaction_uuid=item.transaction_uuid,
                    code="INVALID_PAYLOAD",
                    detail="Mutation payload is invalid",
                    retryable=False,
                )
            )
        except (ValueError, KeyError) as error:
            await db.rollback()
            failures.append(
                SyncFailure(
                    transaction_uuid=item.transaction_uuid,
                    code="INVALID_PAYLOAD",
                    detail=str(error) or "Mutation payload is invalid",
                    retryable=False,
                )
            )
        except DBAPIError:
            await db.rollback()
            failures.append(
                SyncFailure(
                    transaction_uuid=item.transaction_uuid,
                    code="TEMPORARY_DATABASE_ERROR",
                    detail="Temporary database error occurred during replay",
                    retryable=True,
                )
            )
        except Exception:
            await db.rollback()
            failures.append(
                SyncFailure(
                    transaction_uuid=item.transaction_uuid,
                    code="UNKNOWN_ERROR",
                    detail="An unexpected error occurred during replay",
                    retryable=True,
                )
            )
    return SyncBatchResponse(synced_transaction_uuids=synced, failures=failures)
