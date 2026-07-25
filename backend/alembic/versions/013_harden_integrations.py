"""Harden documents and collection-task integrity.

Revision ID: 013_harden_integrations
Revises: 012_business_settings
"""

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "013_harden_integrations"
down_revision: str | None = "012_business_settings"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.drop_constraint(
        "uq_collection_task_installment",
        "collection_task_states",
        type_="unique",
    )
    op.create_index(
        "uq_collection_task_pending_installment",
        "collection_task_states",
        ["loan_id", "installment_number"],
        unique=True,
        postgresql_where=sa.text(
            "status = 'Pending' AND installment_number IS NOT NULL"
        ),
    )
    op.create_check_constraint(
        "ck_collection_tasks_status",
        "collection_task_states",
        "status IN ('Pending', 'Completed', 'Cancelled')",
    )
    op.create_check_constraint(
        "ck_collection_tasks_priority",
        "collection_task_states",
        "priority IN ('Low', 'Normal', 'High', 'Critical')",
    )
    op.create_check_constraint(
        "ck_collection_tasks_promise",
        "collection_task_states",
        "(task_type <> 'PromiseToPay') OR "
        "(promised_amount > 0 AND promise_date IS NOT NULL "
        "AND promise_status IN ('Pending', 'Kept', 'Broken', 'Cancelled'))",
    )
    op.create_check_constraint(
        "ck_documents_size",
        "documents",
        "size_bytes > 0 AND size_bytes <= 700000",
    )
    op.create_check_constraint(
        "ck_documents_content_type",
        "documents",
        "content_type IN ('application/pdf', 'image/jpeg', 'image/png', 'image/webp')",
    )
    op.create_check_constraint(
        "ck_business_settings_currency_code",
        "business_settings",
        "currency_code ~ '^[A-Z]{3}$'",
    )


def downgrade() -> None:
    op.drop_constraint(
        "ck_business_settings_currency_code",
        "business_settings",
        type_="check",
    )
    op.drop_constraint("ck_documents_content_type", "documents", type_="check")
    op.drop_constraint("ck_documents_size", "documents", type_="check")
    op.drop_constraint(
        "ck_collection_tasks_promise",
        "collection_task_states",
        type_="check",
    )
    op.drop_constraint(
        "ck_collection_tasks_priority",
        "collection_task_states",
        type_="check",
    )
    op.drop_constraint(
        "ck_collection_tasks_status",
        "collection_task_states",
        type_="check",
    )
    op.drop_index(
        "uq_collection_task_pending_installment",
        table_name="collection_task_states",
    )
    op.create_unique_constraint(
        "uq_collection_task_installment",
        "collection_task_states",
        ["loan_id", "installment_number"],
    )
