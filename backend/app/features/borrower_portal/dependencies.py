"""FastAPI dependencies for borrower portal security boundary."""

from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.features.auth.service import TokenValidationError
from app.features.borrower_portal.models import BorrowerAccount
from app.features.borrower_portal.service import verify_borrower_access_token

bearer_scheme = HTTPBearer(auto_error=False)
DbSession = Annotated[AsyncSession, Depends(get_db)]


async def get_current_borrower_account(
    db: DbSession,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer_scheme)],
) -> BorrowerAccount:
    """Authenticate client requests using a valid borrower access JWT token."""
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or missing borrower credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise unauthorized

    try:
        payload = verify_borrower_access_token(credentials.credentials)
    except TokenValidationError as error:
        raise unauthorized from error

    account_id = payload["borrower_account_id"]
    stmt = select(BorrowerAccount).where(BorrowerAccount.id == account_id)
    res = await db.execute(stmt)
    account = res.scalar_one_or_none()

    if account is None:
        raise unauthorized
    return account


async def require_active_borrower_account(
    account: Annotated[BorrowerAccount, Depends(get_current_borrower_account)],
) -> BorrowerAccount:
    """Require borrower account status to be Activated or active."""
    if account.account_status != "activated":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Borrower account is {account.account_status}. Only activated accounts may access this resource.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return account


CurrentBorrowerAccount = Annotated[
    BorrowerAccount, Depends(get_current_borrower_account)
]
ActiveBorrowerAccount = Annotated[
    BorrowerAccount, Depends(require_active_borrower_account)
]
