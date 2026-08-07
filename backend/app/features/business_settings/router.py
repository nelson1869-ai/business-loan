"""Persistent non-financial business presentation settings."""

from uuid import uuid4

from fastapi import APIRouter, HTTPException

from app.core.dependencies import CurrentUser, DbSession
from app.features.admin_assistant.models import AuditLog
from app.features.business_settings.models import BusinessSetting
from app.features.business_settings.schemas import (
    BusinessSettingResponse,
    BusinessSettingUpdate,
)

router = APIRouter(prefix="/api/v1/business-settings", tags=["Business Settings"])
_SETTINGS_ID = "default"


@router.get("", response_model=BusinessSettingResponse)
async def get_business_settings(
    db: DbSession, current_user: CurrentUser
) -> BusinessSetting:
    del current_user
    settings = await db.get(BusinessSetting, _SETTINGS_ID)
    if settings is None:
        raise HTTPException(status_code=404, detail="Business settings not initialized")
    return settings


@router.put("", response_model=BusinessSettingResponse)
async def update_business_settings(
    payload: BusinessSettingUpdate,
    db: DbSession,
    current_user: CurrentUser,
) -> BusinessSetting:
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Administrator access required")
    settings = await db.get(BusinessSetting, _SETTINGS_ID)
    if settings is None:
        raise HTTPException(status_code=404, detail="Business settings not initialized")
    settings.business_name = payload.business_name.strip()
    settings.currency_code = payload.currency_code.upper()
    settings.receipt_footer = payload.receipt_footer.strip()
    if payload.timezone is not None:
        settings.timezone = payload.timezone
    settings.default_monthly_estimate_rate = payload.default_monthly_estimate_rate
    db.add(
        AuditLog(
            id=str(uuid4()),
            user_id=current_user.id,
            action="update_business_settings",
            entity_name="business_setting",
            entity_id=_SETTINGS_ID,
            new_state_json='{"values":"[REDACTED]"}',
        )
    )
    await db.commit()
    await db.refresh(settings)
    return settings
