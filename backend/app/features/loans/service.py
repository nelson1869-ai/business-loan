"""Loan service forwarder."""

from app.services.loan_service import (
    create_loan,
    evaluate_workflow_transition,
    get_loan_by_id,
    get_loan_detail,
    list_loans,
    process_workflow_action,
)

__all__ = [
    "create_loan",
    "evaluate_workflow_transition",
    "get_loan_by_id",
    "get_loan_detail",
    "list_loans",
    "process_workflow_action",
]
