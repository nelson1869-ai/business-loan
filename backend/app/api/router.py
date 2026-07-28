"""Central API router registration."""

from fastapi import FastAPI

from app.health import router as health
from app.routers import (
    admin_assistant,
    auth,
    borrowers,
    business_settings,
    collection_tasks,
    documents,
    loans,
    notes,
    notifications,
    payments,
    projections,
    sync,
    users,
)


def register_routers(application: FastAPI) -> None:
    """Register public routes in one reviewable location."""
    for api_router in (
        auth.router,
        admin_assistant.router,
        borrowers.router,
        business_settings.router,
        loans.router,
        notes.router,
        notifications.router,
        collection_tasks.router,
        documents.router,
        payments.router,
        projections.router,
        sync.router,
        users.router,
        health.router,
    ):
        application.include_router(api_router)
