"""Officer note request and response schemas."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.common import to_camel


class NoteCreate(BaseModel):
    """Validated note content supplied by Flutter."""

    content: str = Field(min_length=1, max_length=4000)
    category: str = Field(default="General", min_length=1, max_length=40)


class NoteResponse(BaseModel):
    """Authenticated note representation returned to Flutter."""

    id: str
    borrower_id: str
    loan_id: str | None
    author_user_id: str
    author_name: str
    category: str
    content: str
    created_at: datetime
    can_delete: bool

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)
