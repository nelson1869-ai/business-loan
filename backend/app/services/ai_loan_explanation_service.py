"""Privacy-minimizing AI explanations for deterministic loan schedules."""

from __future__ import annotations

import json
from datetime import UTC, datetime

import httpx
from pydantic import BaseModel, ConfigDict, Field, ValidationError

from app.config import Settings
from app.models.loan import Loan
from app.schemas.loan import LoanExplanationResponse

_SYSTEM_PROMPT = """You explain an existing loan schedule in plain language.
Use only the supplied figures. Do not make approval, eligibility, risk, legal,
or financial-advice recommendations. Do not infer borrower identity.
Return JSON only with this schema:
{"summary":"string","keyPoints":["string"]}
Use 1-3 short key points and do not expose hidden reasoning."""


class AIExplanationUnavailable(RuntimeError):
    """Raised when the optional model integration cannot return a safe response."""


class _ModelExplanation(BaseModel):
    summary: str = Field(min_length=1, max_length=1200)
    key_points: list[str] = Field(
        alias="keyPoints",
        min_length=1,
        max_length=5,
    )


class _LoanExplanationPayload(BaseModel):
    intent: str = "loan_explanation"
    currency: str
    loan_status: str
    original_principal: str
    outstanding_principal: str
    monthly_rate_percent: str
    term_months: int
    payments_per_month: int
    number_of_payments: int
    regular_payment_amount: str
    first_due_date: str
    final_due_date: str

    model_config = ConfigDict(extra="forbid")


def build_safe_loan_context(loan: Loan, currency: str = "PHP") -> dict[str, object]:
    """Build the allowlisted payload sent to the model, excluding borrower PII."""
    return _LoanExplanationPayload(
        currency=currency,
        loan_status=loan.status,
        original_principal=str(loan.original_principal),
        outstanding_principal=str(loan.outstanding_principal),
        monthly_rate_percent=str(loan.monthly_rate * 100),
        term_months=loan.term_months,
        payments_per_month=loan.payments_per_month,
        number_of_payments=loan.number_of_payments,
        regular_payment_amount=str(loan.regular_payment_amount),
        first_due_date=loan.first_due_date.isoformat(),
        final_due_date=loan.final_due_date.isoformat(),
    ).model_dump(mode="json")


def _local_explanation(loan: Loan, settings: Settings) -> LoanExplanationResponse:
    return LoanExplanationResponse(
        summary=(
            f"This {loan.status.lower()} loan has "
            f"{settings.currency_code} {loan.outstanding_principal} outstanding."
        ),
        key_points=[
            f"Regular payment: {settings.currency_code} {loan.regular_payment_amount}.",
            f"Schedule: {loan.number_of_payments} payments through {loan.final_due_date}.",
        ],
        generated_at=datetime.now(UTC),
        model="deterministic-local",
    )


async def explain_loan(
    loan: Loan,
    settings: Settings,
    *,
    transport: httpx.AsyncBaseTransport | None = None,
) -> LoanExplanationResponse:
    """Request and validate a bounded explanation from the configured model."""
    if not settings.ai_explanations_available:
        return _local_explanation(loan, settings)

    base_url = settings.nvidia_base_url
    api_key = settings.nvidia_api_key
    assert base_url is not None and api_key is not None

    request_body = {
        "model": settings.ai_model,
        "messages": [
            {"role": "system", "content": _SYSTEM_PROMPT},
            {
                "role": "user",
                "content": json.dumps(
                    build_safe_loan_context(loan, settings.currency_code),
                    separators=(",", ":"),
                ),
            },
        ],
        "temperature": settings.ai_temperature,
        "top_p": 0.9,
        "max_tokens": settings.ai_max_output_tokens,
        "stream": False,
        "response_format": {"type": "json_object"},
    }

    try:
        async with httpx.AsyncClient(
            base_url=base_url.rstrip("/") + "/",
            headers={"Authorization": f"Bearer {api_key.get_secret_value()}"},
            # The hosted free tier may queue inference, so allow a bounded
            # response window while keeping connection failures fast.
            timeout=httpx.Timeout(settings.ai_timeout_seconds, connect=5.0),
            transport=transport,
        ) as client:
            response = await client.post("chat/completions", json=request_body)
            response.raise_for_status()
        envelope = response.json()
        content = envelope["choices"][0]["message"]["content"]
        parsed = _ModelExplanation.model_validate_json(content)
    except (
        httpx.HTTPError,
        json.JSONDecodeError,
        KeyError,
        IndexError,
        TypeError,
        ValidationError,
    ):
        return _local_explanation(loan, settings)

    summary = parsed.summary.strip()
    key_points = [point.strip() for point in parsed.key_points if point.strip()]
    if not summary or not key_points:
        return _local_explanation(loan, settings)

    return LoanExplanationResponse(
        summary=summary,
        key_points=key_points,
        generated_at=datetime.now(UTC),
        model=settings.ai_model,
    )
