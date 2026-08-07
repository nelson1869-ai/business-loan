"""Unit and API tests for Business Settings endpoints and estimate rate persistence."""

import unittest
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock

from fastapi import HTTPException

from app.features.business_settings import router as business_settings_router
from app.features.business_settings.models import BusinessSetting
from app.features.business_settings.schemas import (
    BusinessSettingUpdate,
)


class TestBusinessSettingsAuthorization(unittest.IsolatedAsyncioTestCase):
    """Test owner authorization enforcement on GET and PUT business settings."""

    async def test_owner_can_get_settings(self) -> None:
        owner = SimpleNamespace(id="owner-1", role="owner")
        mock_setting = BusinessSetting(
            id="default",
            business_name="Lending Nelson",
            currency_code="PHP",
            receipt_footer="",
            timezone="Asia/Manila",
            default_monthly_estimate_rate=Decimal("0.10000000"),
        )
        db = SimpleNamespace(get=AsyncMock(return_value=mock_setting))

        res = await business_settings_router.get_business_settings(db, owner)
        self.assertEqual(res.business_name, "Lending Nelson")
        self.assertEqual(res.default_monthly_estimate_rate, Decimal("0.10000000"))

    async def test_non_owner_get_rejected(self) -> None:
        non_owner = SimpleNamespace(id="user-1", role="borrower")
        db = SimpleNamespace()
        with self.assertRaises(HTTPException) as raised:
            await business_settings_router.get_business_settings(db, non_owner)
        self.assertEqual(raised.exception.status_code, 403)

    async def test_owner_can_update_settings_and_estimate_rate(self) -> None:
        owner = SimpleNamespace(id="owner-1", role="owner")
        mock_setting = BusinessSetting(
            id="default",
            business_name="Old Name",
            currency_code="PHP",
            receipt_footer="",
            timezone="UTC",
            default_monthly_estimate_rate=None,
        )
        db = SimpleNamespace(
            get=AsyncMock(return_value=mock_setting),
            add=AsyncMock(),
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )

        update_payload = BusinessSettingUpdate(
            businessName="New Lending",
            currencyCode="PHP",
            receiptFooter="Thank you!",
            defaultMonthlyEstimateRate=Decimal("0.10000000"),
        )

        await business_settings_router.update_business_settings(
            update_payload, db, owner
        )

        self.assertEqual(mock_setting.business_name, "New Lending")
        self.assertEqual(
            mock_setting.default_monthly_estimate_rate, Decimal("0.10000000")
        )
        db.commit.assert_awaited_once()

    async def test_owner_can_clear_estimate_rate_to_null(self) -> None:
        owner = SimpleNamespace(id="owner-1", role="owner")
        mock_setting = BusinessSetting(
            id="default",
            business_name="Lending",
            currency_code="PHP",
            receipt_footer="",
            timezone="UTC",
            default_monthly_estimate_rate=Decimal("0.10000000"),
        )
        db = SimpleNamespace(
            get=AsyncMock(return_value=mock_setting),
            add=AsyncMock(),
            commit=AsyncMock(),
            refresh=AsyncMock(),
        )

        update_payload = BusinessSettingUpdate(
            businessName="Lending",
            currencyCode="PHP",
            receiptFooter="",
            defaultMonthlyEstimateRate=None,
        )

        await business_settings_router.update_business_settings(
            update_payload, db, owner
        )

        self.assertIsNone(mock_setting.default_monthly_estimate_rate)

    async def test_non_owner_put_rejected(self) -> None:
        non_owner = SimpleNamespace(id="user-1", role="borrower")
        db = SimpleNamespace()
        update_payload = BusinessSettingUpdate(
            businessName="Lending",
            currencyCode="PHP",
            receiptFooter="",
        )
        with self.assertRaises(HTTPException) as raised:
            await business_settings_router.update_business_settings(
                update_payload, db, non_owner
            )
        self.assertEqual(raised.exception.status_code, 403)


class TestBusinessSettingSchemas(unittest.TestCase):
    """Test serialization and float rejection in BusinessSetting schemas."""

    def test_float_estimate_rate_rejected(self) -> None:
        from pydantic import ValidationError

        with self.assertRaises(ValidationError):
            BusinessSettingUpdate(
                businessName="Lending",
                currencyCode="PHP",
                receiptFooter="",
                defaultMonthlyEstimateRate=0.10,  # float disallowed
            )

    def test_string_decimal_estimate_rate_accepted(self) -> None:
        update = BusinessSettingUpdate(
            businessName="Lending",
            currencyCode="PHP",
            receiptFooter="",
            defaultMonthlyEstimateRate=Decimal("0.10000000"),
        )
        self.assertEqual(
            update.default_monthly_estimate_rate, Decimal("0.10000000")
        )
