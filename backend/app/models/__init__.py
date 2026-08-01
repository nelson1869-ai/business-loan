"""SQLAlchemy model exports used by application code and Alembic."""

from app.features.admin_assistant.models import AuditLog
from app.features.automation.models import AutomationEventOutbox
from app.features.borrowers.models import Borrower
from app.features.business_settings.models import BusinessSetting
from app.features.collection.models import CollectionTaskState
from app.features.documents.models import Document
from app.features.loans.models import Installment, Loan
from app.features.notes.models import Note
from app.features.notifications.models import Notification
from app.features.payments.models import Payment, PaymentAllocation
from app.features.sync.models import SyncReceipt
from app.features.users.models import User

__all__ = [
    "AuditLog",
    "AutomationEventOutbox",
    "Borrower",
    "BusinessSetting",
    "CollectionTaskState",
    "Document",
    "Installment",
    "Loan",
    "Note",
    "Notification",
    "Payment",
    "PaymentAllocation",
    "SyncReceipt",
    "User",
]
