"""Collection task ownership and promise workflow regression tests."""

import unittest
from datetime import UTC, date, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock
from uuid import uuid4

from fastapi import HTTPException

from app.routers import collection_tasks
from app.schemas.collection_task import CollectionTaskCreate, PromiseStatusUpdate


class CollectionTaskSecurityTests(unittest.IsolatedAsyncioTestCase):
    async def test_client_generated_task_id_is_preserved(self) -> None:
        task_id = uuid4()
        borrower = SimpleNamespace(id="borrower-1", status="Active")
        loan = SimpleNamespace(id="loan-1", borrower_id="borrower-1")
        assignee = SimpleNamespace(id="admin-1", role="admin")
        added = []
        db = SimpleNamespace(
            get=AsyncMock(side_effect=[borrower, loan, assignee]),
            add=added.append,
            flush=AsyncMock(),
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )
        payload = CollectionTaskCreate(
            id=task_id,
            borrowerId="borrower-1",
            loanId="loan-1",
            taskType="Call",
            dueAt=datetime.now(UTC) + timedelta(hours=1),
        )

        task = await collection_tasks.create_task(payload, db, assignee)

        self.assertEqual(task.id, str(task_id))

    async def test_officer_cannot_assign_another_user(self) -> None:
        borrower = SimpleNamespace(id="borrower-1", status="Active")
        loan = SimpleNamespace(id="loan-1", borrower_id="borrower-1")
        assignee = SimpleNamespace(id="officer-b", role="officer")
        db = SimpleNamespace(get=AsyncMock(side_effect=[borrower, loan, assignee]))
        payload = CollectionTaskCreate(
            borrowerId="borrower-1",
            loanId="loan-1",
            taskType="Call",
            dueAt=datetime.now(UTC) + timedelta(hours=1),
            assignedToUserId="officer-b",
        )

        with self.assertRaises(HTTPException) as raised:
            await collection_tasks.create_task(
                payload,
                db,
                SimpleNamespace(id="officer-a", role="officer"),
            )

        self.assertEqual(raised.exception.status_code, 403)

    async def test_promise_date_cannot_be_in_past(self) -> None:
        borrower = SimpleNamespace(id="borrower-1", status="Active")
        loan = SimpleNamespace(id="loan-1", borrower_id="borrower-1")
        assignee = SimpleNamespace(id="officer-a", role="officer")
        db = SimpleNamespace(get=AsyncMock(side_effect=[borrower, loan, assignee]))
        payload = CollectionTaskCreate(
            borrowerId="borrower-1",
            loanId="loan-1",
            taskType="PromiseToPay",
            dueAt=datetime.now(UTC) + timedelta(hours=1),
            promisedAmount="100.00",
            promiseDate=date(2000, 1, 1),
        )

        with self.assertRaises(HTTPException) as raised:
            await collection_tasks.create_task(
                payload,
                db,
                SimpleNamespace(id="officer-a", role="officer"),
            )

        self.assertEqual(raised.exception.status_code, 422)

    async def test_kept_promise_requires_payment_from_same_loan(self) -> None:
        task = SimpleNamespace(
            id="task-1",
            task_type="PromiseToPay",
            assigned_to_user_id="officer-a",
            promise_status="Pending",
            loan_id="loan-1",
        )
        unrelated_payment = SimpleNamespace(
            id="payment-1",
            loan_id="loan-2",
            entry_type="Payment",
        )
        db = SimpleNamespace(
            scalar=AsyncMock(return_value=task),
            get=AsyncMock(return_value=unrelated_payment),
        )

        with self.assertRaises(HTTPException) as raised:
            await collection_tasks.update_promise_status(
                "task-1",
                PromiseStatusUpdate(
                    promiseStatus="Kept",
                    linkedPaymentId="payment-1",
                ),
                db,
                SimpleNamespace(id="officer-a", role="officer"),
            )

        self.assertEqual(raised.exception.status_code, 422)

    async def test_final_promise_cannot_transition_again(self) -> None:
        task = SimpleNamespace(
            id="task-1",
            task_type="PromiseToPay",
            assigned_to_user_id="officer-a",
            promise_status="Broken",
            loan_id="loan-1",
        )
        db = SimpleNamespace(scalar=AsyncMock(return_value=task))

        with self.assertRaises(HTTPException) as raised:
            await collection_tasks.update_promise_status(
                "task-1",
                PromiseStatusUpdate(promiseStatus="Cancelled"),
                db,
                SimpleNamespace(id="officer-a", role="officer"),
            )

        self.assertEqual(raised.exception.status_code, 409)


if __name__ == "__main__":
    unittest.main()
