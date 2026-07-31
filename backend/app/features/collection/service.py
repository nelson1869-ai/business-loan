"""Collection task service forwarder."""

from app.services.collection_task_service import (
    assign_collection_task,
    get_collection_task_by_id,
    list_collection_tasks,
    update_collection_task_status,
)

__all__ = [
    "assign_collection_task",
    "get_collection_task_by_id",
    "list_collection_tasks",
    "update_collection_task_status",
]
