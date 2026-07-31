"""Ordered offline mutation replay routes."""

from fastapi import APIRouter, HTTPException
from pydantic import ValidationError
from sqlalchemy.exc import DBAPIError, IntegrityError

# Import feature routers for delegate calls
import app.features.business_settings.router as business_settings_router
import app.features.collection.router as collection_router
import app.features.documents.router as documents_router
import app.features.notifications.router as notifications_router
from app.core.dependencies import CurrentUser, DbSession
from app.features.borrowers.schemas import BorrowerCreate, BorrowerUpdate
from app.features.business_settings.schemas import BusinessSettingUpdate
from app.features.collection.schemas import (
    CollectionTaskComplete,
    CollectionTaskCreate,
    PromiseStatusUpdate,
)
from app.features.documents.models import Document
from app.features.documents.schemas import DocumentCreate
from app.features.loans.schemas import LoanCreate
from app.features.notes.models import Note
from app.features.notes.schemas import NoteCreate
from app.features.payments.schemas import PaymentCreate, PaymentReversalCreate
from app.features.sync.models import SyncReceipt
from app.features.sync.schemas import (
    SyncBatchRequest,
    SyncBatchResponse,
    SyncFailure,
    SyncQueueItem,
)
from app.services import borrower_service, loan_service, note_service, payment_service

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

    if item.endpoint.endswith("/notes") and item.method == "POST":
        parts = item.endpoint.split("/")
        borrower_id = parts[4]
        loan_id = parts[6] if len(parts) > 6 else None
        await note_service.create_note(
            db,
            borrower_id,
            NoteCreate.model_validate(item.payload),
            current_user,
            loan_id,
        )
        return

    if item.endpoint.startswith("/api/v1/notes/") and item.method == "DELETE":
        note_id = item.endpoint.rsplit("/", maxsplit=1)[-1]
        note = await db.get(Note, note_id)
        if note is None:
            return
        await note_service.delete_note(db, note, current_user)
        return

    if item.endpoint.endswith("/documents") and item.method == "POST":
        parts = item.endpoint.split("/")
        borrower_id = parts[4]
        loan_id = parts[6] if len(parts) > 6 else None
        await documents_router._create(
            db,
            current_user,
            borrower_id,
            loan_id,
            DocumentCreate.model_validate(item.payload),
        )
        return

    if item.endpoint.startswith("/api/v1/documents/") and item.method == "DELETE":
        document_id = item.endpoint.rsplit("/", maxsplit=1)[-1]
        if await db.get(Document, document_id) is None:
            return
        await documents_router.delete_document(
            document_id,
            db,
            current_user,
        )
        return

    if item.endpoint == "/api/v1/collection-tasks" and item.method == "POST":
        await collection_router.create_task(
            CollectionTaskCreate.model_validate(item.payload),
            db,
            current_user,
        )
        return

    if item.endpoint.startswith("/api/v1/collection-tasks/"):
        parts = item.endpoint.split("/")
        if item.endpoint.endswith("/promise-status") and item.method == "PATCH":
            await collection_router.update_promise_status(
                parts[4],
                PromiseStatusUpdate.model_validate(item.payload),
                db,
                current_user,
            )
            return
        if item.endpoint.endswith("/complete") and item.method == "POST":
            if len(parts) == 6:
                await collection_router.complete_scheduled_task(
                    parts[4],
                    CollectionTaskComplete.model_validate(item.payload),
                    db,
                    current_user,
                )
            else:
                await collection_router.complete_installment_task(
                    parts[4],
                    int(parts[5]),
                    db,
                    current_user,
                )
            return

    if item.endpoint == "/api/v1/notifications/read-all":
        await notifications_router.mark_all_read(db, current_user)
        return

    if item.endpoint == "/api/v1/business-settings" and item.method == "PUT":
        await business_settings_router.update_business_settings(
            BusinessSettingUpdate.model_validate(item.payload),
            db,
            current_user,
        )
        return

    if item.endpoint.startswith("/api/v1/notifications/") and item.endpoint.endswith(
        "/read"
    ):
        await notifications_router.mark_read(
            item.endpoint.split("/")[4],
            db,
            current_user,
        )
        return

    if item.endpoint.startswith("/api/v1/borrowers") or item.endpoint.startswith(
        "/borrowers"
    ):
        borrower_id = item.endpoint.rsplit("/", maxsplit=1)[-1]
        if item.method == "POST":
            if item.endpoint.rstrip("/") not in ("/api/v1/borrowers", "/borrowers"):
                raise SyncReplayError(
                    "UNSUPPORTED_ENDPOINT",
                    f"Endpoint or method is not supported for sync: {item.method} {item.endpoint}",
                    retryable=False,
                )
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

        if item.method in ("PUT", "PATCH"):
            if borrower is None:
                raise SyncReplayError(
                    "RESOURCE_NOT_FOUND", "Borrower does not exist", retryable=False
                )
            payload = BorrowerUpdate.model_validate(item.payload)
            await borrower_service.update_borrower(db, borrower, payload, current_user)
            return

    raise SyncReplayError(
        "UNSUPPORTED_ENDPOINT",
        f"Endpoint or method is not supported for sync: {item.method} {item.endpoint}",
        retryable=False,
    )


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
            receipt = await db.get(SyncReceipt, item.transaction_uuid)
            if receipt is not None:
                if receipt.user_id is not None and receipt.user_id != current_user.id:
                    failures.append(
                        SyncFailure(
                            transaction_uuid=item.transaction_uuid,
                            code="IDEMPOTENCY_CONFLICT",
                            detail="Transaction receipt belongs to another actor",
                            retryable=False,
                        )
                    )
                    continue
                synced.append(item.transaction_uuid)
                continue
            await _replay_item(item, db, current_user)
            db.add(
                SyncReceipt(
                    transaction_uuid=item.transaction_uuid,
                    user_id=current_user.id,
                )
            )
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
        except HTTPException as error:
            await db.rollback()
            failures.append(
                SyncFailure(
                    transaction_uuid=item.transaction_uuid,
                    code=(
                        "IDEMPOTENCY_CONFLICT"
                        if error.status_code == 409
                        else "INVALID_WORKFLOW_STATE"
                    ),
                    detail=str(error.detail),
                    retryable=error.status_code >= 500,
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
