"""Align registration index names with SQLAlchemy metadata.

Revision ID: 033
Revises: 032
"""

from collections.abc import Sequence

from alembic import op

revision: str = "033"
down_revision: str | None = "032"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


RENAMES = {
    "ix_registration_audit_action": "ix_borrower_registration_audits_action",
    "ix_registration_audit_actor": "ix_borrower_registration_audits_actor_user_id",
    "ix_registration_audit_target": "ix_borrower_registration_audits_target_id",
    "ix_registration_linked_borrower": "ix_borrower_registration_requests_linked_borrower_id",
    "ix_registration_phone": "ix_borrower_registration_requests_phone_number_normalized",
    "ix_registration_status": "ix_borrower_registration_requests_status",
    "ix_registration_token_hash": "ix_borrower_registration_requests_status_token_hash",
}


def upgrade() -> None:
    for old_name, new_name in RENAMES.items():
        op.execute(f'ALTER INDEX "{old_name}" RENAME TO "{new_name}"')


def downgrade() -> None:
    for old_name, new_name in reversed(RENAMES.items()):
        op.execute(f'ALTER INDEX "{new_name}" RENAME TO "{old_name}"')
