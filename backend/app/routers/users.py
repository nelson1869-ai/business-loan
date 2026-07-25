"""Administrator-only persistent user management routes."""

from uuid import uuid4

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.dependencies import CurrentUser, DbSession
from app.models.user import User
from app.schemas.user import UserCreate, UserResponse, UserRoleUpdate
from app.services.auth_service import hash_password

router = APIRouter(prefix="/api/v1/users", tags=["Users"])


def _require_admin(current_user: CurrentUser) -> None:
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Administrator access required")


@router.get("", response_model=list[UserResponse])
async def list_users(
    db: DbSession, current_user: CurrentUser
) -> list[User]:
    _require_admin(current_user)
    return list(
        (await db.execute(select(User).order_by(User.username.asc()))).scalars()
    )


@router.post(
    "",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_user(
    payload: UserCreate, db: DbSession, current_user: CurrentUser
) -> User:
    _require_admin(current_user)
    user = User(
        id=str(uuid4()),
        username=payload.username.lower(),
        hashed_password=hash_password(payload.password),
        role=payload.role,
    )
    db.add(user)
    try:
        await db.commit()
    except IntegrityError as error:
        await db.rollback()
        raise HTTPException(status_code=409, detail="Username already exists") from error
    await db.refresh(user)
    return user


@router.patch("/{user_id}/role", response_model=UserResponse)
async def update_user_role(
    user_id: str,
    payload: UserRoleUpdate,
    db: DbSession,
    current_user: CurrentUser,
) -> User:
    _require_admin(current_user)
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    if user.id == current_user.id and payload.role != "admin":
        raise HTTPException(status_code=409, detail="You cannot remove your own administrator role")
    user.role = payload.role
    await db.commit()
    await db.refresh(user)
    return user
