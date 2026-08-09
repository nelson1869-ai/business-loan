"""Administrator-only persistent user management routes."""

from uuid import uuid4

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError

from app.core.authorization import require_owner, require_permission
from app.core.dependencies import CurrentUser, DbSession
from app.features.admin_assistant.models import AuditLog
from app.features.auth.service import hash_password
from app.features.users.models import User
from app.features.users.schemas import UserCreate, UserResponse, UserRoleUpdate

router = APIRouter(prefix="/api/v1/users", tags=["Users"])


def _require_admin(current_user: CurrentUser) -> None:
    require_owner(current_user)


def _audit(db: DbSession, user_id: str, action: str, target_id: str) -> None:
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=user_id,
            action=action,
            entity_name="user",
            entity_id=target_id,
            new_state_json='{"credentials":"[REDACTED]"}',
        )
    )


@router.get("", response_model=list[UserResponse])
async def list_users(db: DbSession, current_user: CurrentUser) -> list[User]:
    _require_admin(current_user)
    return list(
        (
            await db.execute(
                select(User)
                .where(User.role.notin_(["read_only_support", "disabled"]))
                .order_by(User.username.asc())
            )
        ).scalars()
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
    if payload.role not in {"admin", "officer"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only Administrator or Officer roles can be created.",
        )
    user = User(
        id=str(uuid4()),
        username=payload.username.lower(),
        hashed_password=hash_password(payload.password),
        role=payload.role,
    )
    db.add(user)
    _audit(db, current_user.id, "create_user", user.id)
    try:
        await db.commit()
    except IntegrityError as error:
        await db.rollback()
        raise HTTPException(
            status_code=409, detail="Username already exists"
        ) from error
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
    if user.role == "owner":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The emergency owner account cannot be reassigned via standard user management.",
        )
    if payload.role not in {"admin", "officer"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only Administrator or Officer roles can be assigned.",
        )
    if user.id == current_user.id and payload.role != "admin":
        raise HTTPException(
            status_code=409, detail="You cannot remove your own administrator role"
        )
    if user.role == "admin" and payload.role != "admin":
        administrator_count = await db.scalar(
            select(func.count()).select_from(User).where(User.role == "admin")
        )
        if (administrator_count or 0) <= 1:
            raise HTTPException(
                status_code=409,
                detail="The last administrator cannot be demoted",
            )
    user.role = payload.role
    _audit(db, current_user.id, "update_user_role", user.id)
    await db.commit()
    await db.refresh(user)
    return user


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(
    user_id: str,
    db: DbSession,
    current_user: CurrentUser,
) -> None:
    _require_admin(current_user)
    if user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You cannot delete your active admin account.",
        )
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    if user.role == "owner":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The emergency owner account cannot be deleted.",
        )

    try:
        await db.delete(user)
        await db.commit()
    except IntegrityError:
        await db.rollback()
        target_user = await db.get(User, user_id)
        if target_user is not None:
            target_user.role = "read_only_support"
            await db.commit()
