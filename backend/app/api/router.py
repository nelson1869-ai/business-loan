"""Central API router registration."""

from fastapi import FastAPI

from app.core import health
from app.features.admin_assistant import router as admin_assistant
from app.features.auth import router as auth
from app.features.automation import router as automation
from app.features.borrowers import router as borrowers
from app.features.business_settings import router as business_settings
from app.features.collection import router as collection_tasks
from app.features.documents import router as documents
from app.features.loans import router as loans
from app.features.notes import router as notes
from app.features.notifications import router as notifications
from app.features.payments import router as payments
from app.features.projections import router as projections
from app.features.sync import router as sync
from app.features.users import router as users


def register_routers(application: FastAPI) -> None:
    """Register public routes in one reviewable location."""
    for api_router in (
        auth.router,
        admin_assistant.router,
        automation.router,
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
