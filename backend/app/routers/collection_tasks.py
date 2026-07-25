"""Authenticated collection follow-up scheduling and completion."""

from datetime import UTC, datetime
from uuid import uuid4

from fastapi import APIRouter, HTTPException, Query, Response, status
from sqlalchemy import select

from app.dependencies import CurrentUser, DbSession
from app.models.audit_log import AuditLog
from app.models.borrower import Borrower
from app.models.collection_task import CollectionTaskState
from app.models.loan import Installment, Loan
from app.models.notification import Notification
from app.models.user import User
from app.schemas.collection_task import (
    CollectionTaskComplete,
    CollectionTaskCreate,
    CollectionTaskResponse,
    PromiseStatusUpdate,
)

router = APIRouter(prefix="/api/v1/collection-tasks", tags=["Collection Tasks"])


def _audit(db: DbSession, user_id: str, action: str, task_id: str, status_value: str) -> None:
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
        query = query.where(
            CollectionTaskState.assigned_to_user_id == current_user.id
        )
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
    task = CollectionTaskState(
        borrower_id=borrower.id,
        loan_id=loan.id,
        installment_number=payload.installment_number,
        task_type=payload.task_type,
        priority=payload.priority,
        description=payload.description.strip() if payload.description else None,
        due_at=payload.due_at,
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
    task = await db.get(CollectionTaskState, task_id)
    if task is None or task.task_type != "PromiseToPay":
        raise HTTPException(status_code=404, detail="Promise-to-pay task not found")
    if task.assigned_to_user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Task is assigned to another officer")
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
    _audit(db, current_user.id, "update_promise_status", task.id, payload.promise_status)
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
    task = await db.get(CollectionTaskState, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Collection task not found")
    if task.assigned_to_user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Task is assigned to another officer")
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
        query = query.where(
            CollectionTaskState.assigned_to_user_id == current_user.id
        )
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
        select(CollectionTaskState).where(
            CollectionTaskState.loan_id == loan_id,
            CollectionTaskState.installment_number == installment_number,
        )
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
        await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
