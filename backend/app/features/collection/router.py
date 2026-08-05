"""Authenticated collection tasks and cash reconciliation controls."""

import json
from datetime import UTC, datetime
from decimal import Decimal
from uuid import uuid4

from fastapi import APIRouter, HTTPException, Query, Response, status
from sqlalchemy import select

from app.core.authorization import has_permission, require_permission
from app.core.dependencies import CurrentUser, DbSession
from app.features.accounting.service import cash_deposit_lines, post_journal
from app.features.admin_assistant.models import AuditLog
from app.features.borrowers.models import Borrower
from app.features.collection.models import CollectionSession, CollectionTaskState
from app.features.collection.schemas import (
    CollectionSessionCreate,
    CollectionSessionDecision,
    CollectionSessionDeposit,
    CollectionSessionResponse,
    CollectionSessionSubmit,
    CollectionTaskComplete,
    CollectionTaskCreate,
    CollectionTaskResponse,
    PromiseStatusUpdate,
)
from app.features.loans.models import Installment, Loan
from app.features.notifications.models import Notification
from app.features.payments.models import Payment
from app.features.users.models import User

router = APIRouter(prefix="/api/v1/collection-tasks", tags=["Collection Tasks"])
session_router = APIRouter(
    prefix="/api/v1/collection-sessions", tags=["Collection Sessions"]
)


def _session_audit(
    db: DbSession,
    user_id: str,
    action: str,
    session: CollectionSession,
    reason: str | None = None,
) -> None:
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=user_id,
            action=action,
            entity_name="collection_session",
            entity_id=session.id,
            new_state_json=json.dumps(
                {
                    "status": session.status,
                    "expectedCash": str(session.expected_cash),
                    "actualCash": str(session.actual_cash),
                    "cashVariance": str(session.cash_variance),
                    "reason": reason,
                }
            ),
        )
    )


async def _locked_session(db: DbSession, session_id: str) -> CollectionSession:
    session = await db.scalar(
        select(CollectionSession)
        .where(CollectionSession.id == session_id)
        .with_for_update()
    )
    if session is None:
        raise HTTPException(status_code=404, detail="Collection session not found")
    return session


@session_router.post("", response_model=CollectionSessionResponse, status_code=201)
async def open_session(
    payload: CollectionSessionCreate,
    db: DbSession,
    current_user: CurrentUser,
) -> CollectionSession:
    require_permission(current_user, "reconciliation.submit")
    if payload.collector_user_id != current_user.id:
        require_permission(current_user, "reconciliation.approve")
    if await db.get(User, payload.collector_user_id) is None:
        raise HTTPException(status_code=404, detail="Collector not found")
    session = CollectionSession(
        id=str(uuid4()),
        collector_user_id=payload.collector_user_id,
        opened_by_user_id=current_user.id,
        opening_cash=payload.opening_cash,
        expected_cash=payload.opening_cash,
        actual_cash=Decimal("0.00"),
        cash_variance=Decimal("0.00"),
        deposit_amount=Decimal("0.00"),
        status="open",
    )
    db.add(session)
    _session_audit(db, current_user.id, "OPEN_COLLECTION_SESSION", session)
    await db.commit()
    await db.refresh(session)
    return session


@session_router.get("", response_model=list[CollectionSessionResponse])
async def list_sessions(
    db: DbSession, current_user: CurrentUser
) -> list[CollectionSession]:
    query = select(CollectionSession).order_by(CollectionSession.created_at.desc())
    if not has_permission(current_user, "reconciliation.approve"):
        query = query.where(CollectionSession.collector_user_id == current_user.id)
    return list((await db.execute(query)).scalars())


@session_router.post("/{session_id}/submit", response_model=CollectionSessionResponse)
async def submit_session(
    session_id: str,
    payload: CollectionSessionSubmit,
    db: DbSession,
    current_user: CurrentUser,
) -> CollectionSession:
    require_permission(current_user, "reconciliation.submit")
    session = await _locked_session(db, session_id)
    if session.collector_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the collector may submit")
    if session.status not in {"open", "collecting"}:
        raise HTTPException(status_code=409, detail="Session cannot be submitted")
    variance = payload.actual_cash - session.expected_cash
    reason = payload.variance_reason.strip() if payload.variance_reason else None
    if variance != Decimal("0.00") and not reason:
        raise HTTPException(status_code=422, detail="Cash variance requires a reason")
    session.actual_cash = payload.actual_cash
    session.cash_variance = variance
    session.variance_reason = reason
    session.status = "submitted"
    _session_audit(db, current_user.id, "SUBMIT_COLLECTION_SESSION", session, reason)
    await db.commit()
    await db.refresh(session)
    return session


@session_router.post("/{session_id}/review", response_model=CollectionSessionResponse)
async def review_session(
    session_id: str,
    payload: CollectionSessionDecision,
    db: DbSession,
    current_user: CurrentUser,
) -> CollectionSession:
    require_permission(current_user, "reconciliation.approve")
    session = await _locked_session(db, session_id)
    if session.status != "submitted":
        raise HTTPException(
            status_code=409, detail="Only submitted sessions may be reviewed"
        )
    if session.collector_user_id == current_user.id:
        raise HTTPException(
            status_code=403, detail="Collector cannot review own session"
        )
    session.status = "reviewed"
    session.reviewer_user_id = current_user.id
    session.reviewed_at = datetime.now(UTC)
    _session_audit(
        db, current_user.id, "REVIEW_COLLECTION_SESSION", session, payload.reason
    )
    await db.commit()
    await db.refresh(session)
    return session


@session_router.post(
    "/{session_id}/reconcile", response_model=CollectionSessionResponse
)
async def reconcile_session(
    session_id: str,
    payload: CollectionSessionDecision,
    db: DbSession,
    current_user: CurrentUser,
) -> CollectionSession:
    require_permission(current_user, "reconciliation.approve")
    session = await _locked_session(db, session_id)
    if session.status != "reviewed" or session.reviewer_user_id != current_user.id:
        raise HTTPException(status_code=409, detail="Reviewed session required")
    session.status = "reconciled"
    session.reconciled_at = datetime.now(UTC)
    payments = (
        await db.execute(
            select(Payment).where(
                Payment.collection_session_id == session.id,
                Payment.entry_type == "Payment",
            )
        )
    ).scalars()
    for payment in payments:
        payment.reconciliation_status = "reconciled"
    _session_audit(
        db, current_user.id, "RECONCILE_COLLECTION_SESSION", session, payload.reason
    )
    await db.commit()
    await db.refresh(session)
    return session


@session_router.post("/{session_id}/deposit", response_model=CollectionSessionResponse)
async def deposit_session(
    session_id: str,
    payload: CollectionSessionDeposit,
    db: DbSession,
    current_user: CurrentUser,
) -> CollectionSession:
    require_permission(current_user, "reconciliation.approve")
    session = await _locked_session(db, session_id)
    if session.status != "reconciled":
        raise HTTPException(status_code=409, detail="Reconciled session required")
    if payload.amount != session.actual_cash:
        raise HTTPException(status_code=422, detail="Deposit must equal actual cash")
    session.deposit_amount = payload.amount
    session.deposit_reference = payload.reference.strip()
    session.deposited_at = datetime.now(UTC)
    session.status = "deposited"
    await post_journal(
        db,
        actor=current_user,
        currency="PHP",
        posted_at=session.deposited_at,
        source_type="cash_deposit",
        source_record_id=session.id,
        idempotency_key=f"cash-deposit:{session.id}",
        description=f"Collection session {session.id} cash deposit",
        lines=cash_deposit_lines(payload.amount),
    )
    _session_audit(db, current_user.id, "DEPOSIT_COLLECTION_SESSION", session)
    await db.commit()
    await db.refresh(session)
    return session


@session_router.post("/{session_id}/close", response_model=CollectionSessionResponse)
async def close_session(
    session_id: str,
    payload: CollectionSessionDecision,
    db: DbSession,
    current_user: CurrentUser,
) -> CollectionSession:
    require_permission(current_user, "reconciliation.approve")
    session = await _locked_session(db, session_id)
    if session.status != "deposited":
        raise HTTPException(status_code=409, detail="Deposited session required")
    if session.cash_variance != Decimal("0.00") and not session.variance_reason:
        raise HTTPException(
            status_code=409, detail="Unexplained variance blocks closure"
        )
    session.status = "closed"
    session.closed_at = datetime.now(UTC)
    _session_audit(
        db, current_user.id, "CLOSE_COLLECTION_SESSION", session, payload.reason
    )
    await db.commit()
    await db.refresh(session)
    return session


async def _locked_task(db: DbSession, task_id: str) -> CollectionTaskState | None:
    return await db.scalar(
        select(CollectionTaskState)
        .where(CollectionTaskState.id == task_id)
        .with_for_update()
    )


def _audit(
    db: DbSession, user_id: str, action: str, task_id: str, status_value: str
) -> None:
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=user_id,
            action=action,
            entity_name="collection_task",
            entity_id=task_id,
            new_state_json=f'{{"status":"{status_value}"}}',
        )
    )


@router.get("", response_model=list[CollectionTaskResponse])
async def list_tasks(
    db: DbSession,
    current_user: CurrentUser,
    task_status: str | None = Query(default=None, alias="status"),
) -> list[CollectionTaskState]:
    query = select(CollectionTaskState).order_by(CollectionTaskState.due_at)
    if current_user.role != "admin":
        query = query.where(CollectionTaskState.assigned_to_user_id == current_user.id)
    if task_status:
        query = query.where(CollectionTaskState.status == task_status)
    return list((await db.execute(query)).scalars())


@router.post(
    "",
    response_model=CollectionTaskResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_task(
    payload: CollectionTaskCreate,
    db: DbSession,
    current_user: CurrentUser,
) -> CollectionTaskState:
    borrower = await db.get(Borrower, payload.borrower_id)
    loan = await db.get(Loan, payload.loan_id)
    assignee_id = payload.assigned_to_user_id or current_user.id
    assignee = await db.get(User, assignee_id)
    if borrower is None or borrower.status == "Deleted":
        raise HTTPException(status_code=404, detail="Borrower not found")
    if loan is None or loan.borrower_id != borrower.id:
        raise HTTPException(status_code=404, detail="Loan not found for borrower")
    if assignee is None:
        raise HTTPException(status_code=404, detail="Assigned officer not found")
    if assignee_id != current_user.id and current_user.role != "admin":
        raise HTTPException(
            status_code=403,
            detail="Only administrators may assign tasks to another user",
        )
    now = datetime.now(UTC)
    due_at = (
        payload.due_at.replace(tzinfo=UTC)
        if payload.due_at.tzinfo is None
        else payload.due_at.astimezone(UTC)
    )
    if due_at <= now:
        raise HTTPException(
            status_code=422, detail="Follow-up date must be in the future"
        )
    if payload.installment_number is not None:
        installment = await db.scalar(
            select(Installment).where(
                Installment.loan_id == loan.id,
                Installment.installment_number == payload.installment_number,
            )
        )
        if installment is None:
            raise HTTPException(status_code=404, detail="Installment not found")
    if payload.task_type == "PromiseToPay" and (
        payload.promised_amount is None or payload.promise_date is None
    ):
        raise HTTPException(
            status_code=422,
            detail="Promise-to-pay requires promisedAmount and promiseDate",
        )
    if (
        payload.task_type == "PromiseToPay"
        and payload.promise_date is not None
        and payload.promise_date < now.date()
    ):
        raise HTTPException(
            status_code=422, detail="Promise date cannot be in the past"
        )
    task = CollectionTaskState(
        id=str(payload.id) if payload.id is not None else str(uuid4()),
        borrower_id=borrower.id,
        loan_id=loan.id,
        installment_number=payload.installment_number,
        task_type=payload.task_type,
        priority=payload.priority,
        description=payload.description.strip() if payload.description else None,
        due_at=due_at,
        created_by_user_id=current_user.id,
        assigned_to_user_id=assignee_id,
        promised_amount=payload.promised_amount,
        promise_date=payload.promise_date,
        promise_status="Pending" if payload.task_type == "PromiseToPay" else None,
    )
    db.add(task)
    db.add(
        Notification(
            user_id=assignee_id,
            category="Collections",
            priority=payload.priority,
            title=f"{payload.task_type} follow-up assigned",
            body=payload.description or "A collection follow-up was assigned to you.",
            borrower_id=borrower.id,
            loan_id=loan.id,
        )
    )
    await db.flush()
    _audit(db, current_user.id, "create_collection_task", task.id, "Pending")
    await db.commit()
    await db.refresh(task)
    return task


@router.patch(
    "/{task_id}/promise-status",
    response_model=CollectionTaskResponse,
)
async def update_promise_status(
    task_id: str,
    payload: PromiseStatusUpdate,
    db: DbSession,
    current_user: CurrentUser,
) -> CollectionTaskState:
    task = await _locked_task(db, task_id)
    if task is None or task.task_type != "PromiseToPay":
        raise HTTPException(status_code=404, detail="Promise-to-pay task not found")
    if task.assigned_to_user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(
            status_code=403, detail="Task is assigned to another officer"
        )
    if task.promise_status != "Pending":
        raise HTTPException(status_code=409, detail="Promise status is already final")
    linked_payment = None
    if payload.linked_payment_id is not None:
        linked_payment = await db.get(Payment, payload.linked_payment_id)
    if payload.promise_status == "Kept":
        if (
            linked_payment is None
            or linked_payment.loan_id != task.loan_id
            or linked_payment.entry_type != "Payment"
        ):
            raise HTTPException(
                status_code=422,
                detail="A kept promise requires a payment from the same loan",
            )
    elif payload.linked_payment_id is not None:
        raise HTTPException(
            status_code=422,
            detail="Only a kept promise may link a payment",
        )
    task.promise_status = payload.promise_status
    task.linked_payment_id = payload.linked_payment_id
    if payload.promise_status == "Broken":
        db.add(
            Notification(
                user_id=task.assigned_to_user_id,
                category="Overdue",
                priority="High",
                title="Promise to pay broken",
                body="A borrower promise-to-pay requires follow-up.",
                borrower_id=task.borrower_id,
                loan_id=task.loan_id,
            )
        )
    _audit(
        db, current_user.id, "update_promise_status", task.id, payload.promise_status
    )
    await db.commit()
    await db.refresh(task)
    return task


@router.post(
    "/{task_id}/complete",
    response_model=CollectionTaskResponse,
)
async def complete_scheduled_task(
    task_id: str,
    payload: CollectionTaskComplete,
    db: DbSession,
    current_user: CurrentUser,
) -> CollectionTaskState:
    task = await _locked_task(db, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Collection task not found")
    if task.assigned_to_user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(
            status_code=403, detail="Task is assigned to another officer"
        )
    if task.status != "Completed":
        task.status = "Completed"
        task.completed_by_user_id = current_user.id
        task.completed_at = datetime.now(UTC)
        task.completion_note = (
            payload.completion_note.strip() if payload.completion_note else None
        )
        _audit(db, current_user.id, "complete_collection_task", task.id, "Completed")
        await db.commit()
        await db.refresh(task)
    return task


@router.get("/completed", response_model=list[str])
async def completed_installment_tasks(
    db: DbSession, current_user: CurrentUser
) -> list[str]:
    query = select(CollectionTaskState).where(
        CollectionTaskState.status == "Completed",
        CollectionTaskState.installment_number.is_not(None),
    )
    if current_user.role != "admin":
        query = query.where(CollectionTaskState.assigned_to_user_id == current_user.id)
    rows = (await db.execute(query)).scalars()
    return [f"{row.loan_id}:{row.installment_number}" for row in rows]


@router.post(
    "/{loan_id}/{installment_number}/complete",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def complete_installment_task(
    loan_id: str,
    installment_number: int,
    db: DbSession,
    current_user: CurrentUser,
) -> Response:
    installment = await db.scalar(
        select(Installment).where(
            Installment.loan_id == loan_id,
            Installment.installment_number == installment_number,
        )
    )
    loan = await db.get(Loan, loan_id)
    if installment is None or loan is None:
        raise HTTPException(status_code=404, detail="Installment not found")
    task = await db.scalar(
        select(CollectionTaskState)
        .where(
            CollectionTaskState.loan_id == loan_id,
            CollectionTaskState.installment_number == installment_number,
            CollectionTaskState.status == "Pending",
        )
        .with_for_update()
    )
    if (
        task is not None
        and task.assigned_to_user_id != current_user.id
        and current_user.role != "admin"
    ):
        raise HTTPException(
            status_code=403,
            detail="Task is assigned to another officer",
        )
    if task is None:
        task = CollectionTaskState(
            borrower_id=loan.borrower_id,
            loan_id=loan_id,
            installment_number=installment_number,
            task_type="Visit",
            priority="High" if installment.status == "Overdue" else "Normal",
            status="Completed",
            due_at=datetime.combine(installment.due_date, datetime.min.time(), UTC),
            created_by_user_id=current_user.id,
            assigned_to_user_id=current_user.id,
            completed_by_user_id=current_user.id,
            completed_at=datetime.now(UTC),
        )
        db.add(task)
        await db.flush()
        _audit(db, current_user.id, "complete_collection_task", task.id, "Completed")
    else:
        task.status = "Completed"
        task.completed_by_user_id = current_user.id
        task.completed_at = datetime.now(UTC)
        _audit(db, current_user.id, "complete_collection_task", task.id, "Completed")
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
