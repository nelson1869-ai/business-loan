"""Reproducible report response schemas."""

from datetime import date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict

from app.core.schemas.common import to_camel


class AgingBuckets(BaseModel):
    current: Decimal
    days_1_7: Decimal
    days_8_30: Decimal
    days_31_60: Decimal
    days_61_90: Decimal
    days_over_90: Decimal

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class PortfolioRiskReport(BaseModel):
    as_of: date
    timezone: str
    currency: str
    outstanding_principal: Decimal
    accrued_interest: Decimal
    interest_collected: Decimal
    par_1: Decimal
    par_7: Decimal
    par_30: Decimal
    par_60: Decimal
    par_90: Decimal
    aging: AgingBuckets

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class CollectorReconciliationRow(BaseModel):
    session_id: str
    collector_user_id: str
    reviewer_user_id: str | None
    opening_cash: Decimal
    cash_collected: Decimal
    non_cash_payments: Decimal
    expected_cash: Decimal
    actual_cash: Decimal
    variance: Decimal
    deposit_amount: Decimal
    deposit_reference: str | None
    status: str

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class CollectorReconciliationReport(BaseModel):
    date_from: date
    date_to: date
    timezone: str
    currency: str
    rows: list[CollectorReconciliationRow]

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class WriteOffReportRow(BaseModel):
    loan_id: str
    write_off_date: date
    written_off_amount: Decimal
    recovered_amount: Decimal
    unrecovered_amount: Decimal

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)


class WriteOffReport(BaseModel):
    date_from: date
    date_to: date
    currency: str
    total_written_off: Decimal
    total_recovered: Decimal
    rows: list[WriteOffReportRow]

    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)
