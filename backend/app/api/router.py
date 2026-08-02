"""Central API router registration."""

from fastapi import FastAPI

from app.core import health
from app.features.accounting import router as accounting
from app.features.admin_assistant import router as admin_assistant
from app.features.approvals import router as approvals
from app.features.auth import router as auth
from app.features.automation import router as automation
from app.features.borrower_portal import router as borrower_portal
from app.features.borrowers import router as borrowers
from app.features.business_settings import router as business_settings
from app.features.collection import router as collection_tasks
from app.features.documents import router as documents
from app.features.loan_policies import router as loan_policies
from app.features.loans import router as loans
from app.features.notes import router as notes
from app.features.notifications import router as notifications
from app.features.payments import router as payments
from app.features.projections import router as projections
from app.features.reports import router as reports
from app.features.sync import router as sync
from app.features.users import router as users
from app.features.write_offs import router as write_offs


def register_routers(application: FastAPI) -> None:
    """Register public routes in one reviewable location."""
    for api_router in (
        auth.router,
        accounting.router,
        approvals.router,
        admin_assistant.router,
        automation.router,
        borrowers.router,
        borrower_portal.client_router,
        borrower_portal.officer_router,
        business_settings.router,
        loans.router,
        loan_policies.router,
        notes.router,
        notifications.router,
        collection_tasks.router,
        collection_tasks.session_router,
        documents.router,
        payments.router,
        projections.router,
        reports.router,
        sync.router,
        users.router,
        write_offs.router,
        health.router,
    ):
        application.include_router(api_router)
