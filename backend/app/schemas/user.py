"""Administrative user account schemas."""

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.common import to_camel

UserRole = Literal["admin", "officer"]


class UserCreate(BaseModel):
    username: str = Field(min_length=3, max_length=100, pattern=r"^[A-Za-z0-9._-]+$")
    password: str = Field(min_length=12, max_length=72)
    role: UserRole = "officer"


class UserRoleUpdate(BaseModel):
    role: UserRole


class UserResponse(BaseModel):
    id: str
    username: str
    role: str
    created_at: datetime

    model_config = ConfigDict(
        alias_generator=to_camel, populate_by_name=True, from_attributes=True
    )
