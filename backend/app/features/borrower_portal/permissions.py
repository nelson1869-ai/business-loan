"""Borrower authorization and record ownership rules."""

from fastapi import HTTPException, status

from app.features.borrower_portal.models import BorrowerAccount


def enforce_borrower_ownership(
    account: BorrowerAccount,
    target_borrower_id: str,
) -> None:
    """Enforce that access to resources belongs strictly to the authenticated borrower."""
    if account.borrower_id != target_borrower_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access forbidden for requested resource",
        )
