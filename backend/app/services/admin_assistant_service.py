"""Deterministic, privacy-preserving administrative assistant orchestration."""

from __future__ import annotations

import hashlib
import json
import logging
import re
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal
from difflib import SequenceMatcher
from time import monotonic
from typing import Any, Callable, Literal
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import httpx
from pydantic import BaseModel, ConfigDict, Field, ValidationError
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import Settings
from app.models.borrower import Borrower
from app.models.business_setting import BusinessSetting
from app.models.loan import Installment, Loan
from app.schemas.admin_assistant import (
    AdminAssistantRecord,
    AdminAssistantResponse,
    AssistantIntent,
    BorrowerClarification,
    BorrowerClarificationOption,
)
from app.services import projection_service

logger = logging.getLogger(__name__)
ZERO = Decimal("0.00")
_DISPLAY_LIMIT = 50
_BORROWER_INTENTS = {
    "borrower_principal",
    "borrower_balance",
    "borrower_next_payment",
    "borrower_overdue_installments",
    "borrower_payment_history",
    "borrower_loan_summary",
}


class UnsupportedAssistantQuestion(ValueError):
    """Raised when a question is outside the approved intent catalog."""


class BorrowerNotFound(LookupError):
    """Raised when no authorized borrower matches the local reference."""


@dataclass(frozen=True)
class IntentRoute:
    """Privacy-safe local route decision for one assistant request."""

    intent: AssistantIntent
    route: str
    confidence: int


class AnonymousAIPayload(BaseModel):
    """The complete and exclusive schema permitted to leave the backend."""

    intent: Literal["portfolio_summary", "borrower_loan_summary"]
    currency: str
    loan_status: str | None = None
    outstanding_balance: str | None = None
    total_paid: str | None = None
    overdue_installments: int | None = None
    next_due_date: date | None = None
    active_loans: int | None = None
    overdue_loans: int | None = None
    due_today: str | None = None

    model_config = ConfigDict(extra="forbid")


class ProviderChatMessage(BaseModel):
    """Strict subset of an OpenAI-compatible provider message."""

    content: str = Field(min_length=1, max_length=1200)

    model_config = ConfigDict(extra="ignore", strict=True)


class ProviderChatChoice(BaseModel):
    """Strict subset of one provider choice."""

    message: ProviderChatMessage

    model_config = ConfigDict(extra="ignore", strict=True)


class ProviderChatCompletion(BaseModel):
    """Validated provider response envelope."""

    choices: list[ProviderChatChoice] = Field(min_length=1, max_length=10)

    model_config = ConfigDict(extra="ignore", strict=True)


_AI_ALLOWED_FIELDS = frozenset(AnonymousAIPayload.model_fields)


def assert_ai_payload_allowlisted(payload: AnonymousAIPayload) -> dict[str, object]:
    """Fail closed if any external payload field is outside the static allowlist."""
    data = payload.model_dump(mode="json", exclude_none=True)
    unexpected = set(data) - _AI_ALLOWED_FIELDS
    if unexpected:
        raise ValueError("External AI payload contains non-allowlisted fields")
    serialized = json.dumps(data, sort_keys=True).lower()
    forbidden_markers = (
        "borrower_id",
        "borrower_name",
        "loan_id",
        "user_id",
        "phone",
        "national_id",
        "address",
        "email",
        "government_id",
        "notes",
        "documents",
        "message",
        "prompt",
    )
    if any(marker in serialized for marker in forbidden_markers):
        raise ValueError("External AI payload contains identifying fields")
    return data


def classify_question(message: str) -> AssistantIntent:
    """Resolve an intent locally without model-generated tools or arguments."""
    text = _normalize_phrase(message)
    if text.strip("!.,? ") in {"hi", "hello", "hey", "help"}:
        return "help"
    if any(
        term in text
        for term in (
            "list borrower",
            "list of borrower",
            "show borrower",
            "show all borrower",
            "borrower directory",
            "all borrower",
            "find borrower",
            "search borrower",
            "search for borrower",
            "borrowers",
        )
    ):
        return "borrower_directory"
    if "overdue installment" in text and not any(
        token in text for token in ("which accounts", "how many", "all overdue")
    ):
        return "borrower_overdue_installments"
    if "summarize" in text and any(
        token in text for token in ("loan position", "borrower's current loan")
    ):
        return "borrower_loan_summary"
    borrower_hint = any(
        token in text
        for token in (
            "borrower",
            "borrowed",
            "borrow",
            "loan amount",
            "principal",
            "owe",
            "owes",
            "next payment",
            "payment history",
            "payments made",
        )
    )
    if borrower_hint:
        if any(
            token in text
            for token in (
                "how much borrowed",
                "how much borrow",
                "how much did",
                "how much they borrow",
                "how much loan",
                "borrow amount",
                "borrowed amount",
                "loan amount",
                "original principal",
            )
        ):
            return "borrower_principal"
        if (
            "history" in text
            or "payments made" in text
            or "payment history" in text
            or "ledger" in text
            or "past payments" in text
        ):
            return "borrower_payment_history"
        if (
            "next" in text
            or "due date" in text
        ) and ("payment" in text or "due" in text):
            return "borrower_next_payment"
        if (
            "overdue" in text
            or "late installment" in text
            or "late" in text
        ):
            return "borrower_overdue_installments"
        if "summary" in text or "position" in text or "details" in text or "status" in text or "profile" in text:
            return "borrower_loan_summary"
        if any(
            token in text
            for token in (
                "owe",
                "owes",
                "balance",
                "outstanding",
            )
        ):
            return "borrower_balance"
        return "borrower_balance"
    if any(
        term in text
        for term in (
            "not paid today",
            "unpaid today",
            "due today",
            "unpaid installments",
        )
    ):
        return "unpaid_today"
    if "tomorrow" in text and any(
        term in text for term in ("due", "pay", "payment")
    ):
        return "due_tomorrow"
    if any(
        term in text
        for term in (
            "overdue",
            "late payment",
            "past due",
            "late",
        )
    ):
        return "overdue"
    if any(
        term in text
        for term in (
            "income",
            "collected",
            "collection",
            "collections",
            "received",
            "repayment",
            "repayments",
        )
    ):
        return "collections_this_month"
    if any(
        term in text
        for term in (
            "portfolio",
            "business performance",
            "dashboard summary",
            "active loans",
            "outstanding",
            "business",
        )
    ):
        return "portfolio_summary"
    raise UnsupportedAssistantQuestion(
        "I couldn't match that question. Try borrower lists, collections, due "
        "or overdue accounts, portfolio performance, or a borrower's loan details."
    )


def _normalize_phrase(message: str) -> str:
    text = message.lower().replace("’", "'").replace("-", " ")
    text = re.sub(r"[^a-z0-9' ]", " ", text)
    return " ".join(text.split())


def route_question(message: str) -> IntentRoute:
    """Classify locally and expose a conservative route confidence score."""
    intent = classify_question(message)
    text = _normalize_phrase(message)
    exact_suggestions = {
        "how much was collected this month?": "collections_this_month",
        "who has not paid today?": "unpaid_today",
        "who is due tomorrow?": "due_tomorrow",
        "show overdue accounts": "overdue",
        "summarize portfolio performance": "portfolio_summary",
        "list borrowers": "borrower_directory",
    }
    if exact_suggestions.get(text) == intent:
        confidence = 100
    elif intent == "help":
        confidence = 100
    elif intent == "borrower_directory":
        confidence = 98
    elif intent in _BORROWER_INTENTS:
        has_name_like_reference = len(re.findall(r"\b[A-Z][a-z]+\b", message)) >= 2
        has_pronoun = bool(
            re.search(r"\b(they|them|their)\b|(?:this|that|the) borrower", text)
        )
        confidence = 92 if has_name_like_reference else 82 if has_pronoun else 86
    elif intent in {"unpaid_today", "due_tomorrow", "collections_this_month"}:
        confidence = 96
    else:
        confidence = 90
    if confidence < 80:
        raise UnsupportedAssistantQuestion(
            "I couldn't match that question confidently. Please rephrase it."
        )
    return IntentRoute(
        intent=intent,
        route=f"admin_assistant.{intent}",
        confidence=confidence,
    )


def business_date(settings: Settings, now: datetime | None = None) -> date:
    """Return the configured business date without relying on server-local time."""
    try:
        zone = ZoneInfo(settings.business_timezone)
    except ZoneInfoNotFoundError as error:
        raise ValueError("Invalid business timezone configuration") from error
    instant = now or datetime.now(UTC)
    return instant.astimezone(zone).date()


def should_use_ai(
    intent: AssistantIntent,
    metrics: dict[str, str | int],
    user_preferences: dict[str, object] | None = None,
) -> bool:
    """Conserve free-tier calls; factual values and record lists remain local."""
    del metrics
    if user_preferences and user_preferences.get("disable_ai") is True:
        return False
    return intent in {"portfolio_summary", "borrower_loan_summary"}


@dataclass
class _CacheEntry:
    answer: str
    expires_at: float


class _AIState:
    def __init__(self) -> None:
        self.cache: dict[str, _CacheEntry] = {}
        self.consecutive_failures = 0
        self.cooldown_until = 0.0


_ai_state = _AIState()


async def _enhance_with_ai(
    payload: AnonymousAIPayload,
    settings: Settings,
    *,
    transport: httpx.AsyncBaseTransport | None = None,
) -> tuple[str | None, str]:
    """Make at most one bounded, anonymous provider request with cooldown/cache."""
    if not settings.ai_explanations_available:
        return None, "disabled"
    now = monotonic()
    if now < _ai_state.cooldown_until:
        return None, "cooldown"
    safe_payload = assert_ai_payload_allowlisted(payload)
    digest = hashlib.sha256(
        json.dumps(safe_payload, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    cached = _ai_state.cache.get(digest)
    if cached and cached.expires_at > now:
        return cached.answer, "enhanced"

    request = {
        "model": settings.ai_model,
        "messages": [
            {
                "role": "system",
                "content": (
                    "Rephrase verified anonymous lending facts in at most two "
                    "sentences. Never add figures, advice, names, or reasoning."
                ),
            },
            {
                "role": "user",
                "content": json.dumps(safe_payload, separators=(",", ":")),
            },
        ],
        "temperature": settings.ai_temperature,
        "max_tokens": settings.ai_max_output_tokens,
        "stream": False,
    }
    status = "unavailable"
    try:
        assert settings.nvidia_api_key and settings.nvidia_base_url
        async with httpx.AsyncClient(
            base_url=settings.nvidia_base_url.rstrip("/") + "/",
            headers={
                "Authorization": f"Bearer {settings.nvidia_api_key.get_secret_value()}"
            },
            timeout=httpx.Timeout(settings.ai_timeout_seconds, connect=5.0),
            transport=transport,
        ) as client:
            for attempt in range(settings.ai_max_retries + 1):
                try:
                    response = await client.post("chat/completions", json=request)
                    if response.status_code == 429:
                        status = "rate_limited"
                        raise httpx.HTTPStatusError(
                            "rate limited",
                            request=response.request,
                            response=response,
                        )
                    response.raise_for_status()
                    break
                except httpx.HTTPStatusError as error:
                    retryable = error.response.status_code >= 500
                    if (
                        error.response.status_code != 429
                        and retryable
                        and attempt < settings.ai_max_retries
                    ):
                        continue
                    raise
                except httpx.TransportError:
                    if attempt < settings.ai_max_retries:
                        continue
                    raise
        try:
            completion = ProviderChatCompletion.model_validate(response.json())
        except ValueError, ValidationError:
            return None, "invalid_response"
        answer = completion.choices[0].message.content.strip()
        allowed_numbers = set(re.findall(r"\d+(?:\.\d+)?", json.dumps(safe_payload)))
        generated_numbers = set(re.findall(r"\d+(?:\.\d+)?", answer.replace(",", "")))
        prohibited = (
            "approve",
            "approval",
            "reject",
            "rejection",
            "creditworthy",
            "recommend",
            "advice",
            "legal action",
            "legal advice",
            "risk score",
            "change the rate",
            "improving",
            "declining",
            "healthy",
            "risky",
            "strong",
            "weak",
            "likely to pay",
            "unlikely to pay",
            "threaten",
            "seize",
            "arrest",
            "collection threat",
        )
        if not generated_numbers.issubset(allowed_numbers) or any(
            term in answer.lower() for term in prohibited
        ):
            return None, "invalid_response"
        _ai_state.consecutive_failures = 0
        if settings.ai_cache_ttl_seconds:
            _ai_state.cache[digest] = _CacheEntry(
                answer=answer,
                expires_at=now + settings.ai_cache_ttl_seconds,
            )
        return answer, "enhanced"
    except (
        httpx.HTTPError,
        IndexError,
        TypeError,
        ValueError,
        ValidationError,
    ) as error:
        _ai_state.consecutive_failures += 1
        if _ai_state.consecutive_failures >= 3:
            _ai_state.cooldown_until = now + settings.ai_failure_cooldown_seconds
        logger.warning(
            "assistant_ai_fallback",
            extra={
                "intent": payload.intent,
                "provider_status": status,
                "failure_type": type(error).__name__,
            },
        )
        return None, status


async def _resolve_borrower(
    db: AsyncSession,
    message: str,
    selected_borrower_id: str | None,
    borrower_scope: Callable[[Any], Any] | None = None,
) -> tuple[Borrower | None, BorrowerClarification | None]:
    scope = borrower_scope or apply_admin_borrower_scope
    if selected_borrower_id:
        borrower = (
            await db.execute(
                scope(select(Borrower).where(Borrower.id == selected_borrower_id))
            )
        ).scalar_one_or_none()
        if borrower is None:
            raise BorrowerNotFound("Borrower not found")
        return borrower, None

    normalized_message = re.sub(r"[^a-z0-9 ]", " ", message.lower())
    normalized_message = " ".join(normalized_message.split())
    name_tokens = _borrower_name_tokens(normalized_message)
    name_ngrams = {
        " ".join(name_tokens[start:end])
        for start in range(len(name_tokens))
        for end in range(start + 2, min(len(name_tokens), start + 4) + 1)
    }
    full_name = func.lower(Borrower.first_name + " " + Borrower.last_name)
    exact_candidates: list[Borrower] = []
    if name_ngrams:
        exact_candidates = list(
            (
                await db.execute(
                    scope(select(Borrower))
                    .where(full_name.in_(name_ngrams))
                    .order_by(Borrower.last_name, Borrower.first_name)
                    .limit(20)
                )
            ).scalars()
        )
    if exact_candidates:
        borrowers = exact_candidates
    else:
        partial_conditions = [
            or_(
                func.lower(Borrower.first_name).contains(token[:3]),
                func.lower(Borrower.last_name).contains(token[:3]),
            )
            for token in name_tokens
        ]
        statement = scope(select(Borrower))
        if partial_conditions:
            statement = statement.where(or_(*partial_conditions))
        borrowers = list(
            (
                await db.execute(
                    statement.order_by(Borrower.last_name, Borrower.first_name).limit(
                        50
                    )
                )
            ).scalars()
        )
    exact: list[Borrower] = []
    partial: list[Borrower] = []
    scored: list[tuple[float, Borrower]] = []
    for borrower in borrowers:
        full_name = f"{borrower.first_name} {borrower.last_name}".strip().lower()
        normalized_name = re.sub(r"[^a-z0-9 ]", " ", full_name)
        if normalized_name and normalized_name in normalized_message:
            exact.append(borrower)
        elif any(len(token) >= 3 and token in normalized_name for token in name_tokens):
            partial.append(borrower)
        else:
            words = normalized_message.split()
            name_word_count = max(1, len(normalized_name.split()))
            windows = [
                " ".join(words[index : index + name_word_count])
                for index in range(max(1, len(words) - name_word_count + 1))
            ]
            score = max(
                (
                    SequenceMatcher(None, normalized_name, window).ratio()
                    for window in windows
                ),
                default=0.0,
            )
            if score >= 0.62:
                scored.append((score, borrower))
    padded_message = f" {normalized_message} "
    refers_to_previous = any(
        phrase in padded_message
        for phrase in (
            " they ",
            " them ",
            " their ",
            " that borrower ",
            " this borrower ",
            " the borrower ",
        )
    )
    if not exact and refers_to_previous and len(borrowers) >= 2:
        options = [
            BorrowerClarificationOption(
                borrower_id=item.id,
                display_name=f"{item.first_name} {item.last_name}".strip(),
                masked_reference=f"Borrower ••••{item.id[-4:]}",
            )
            for item in borrowers[:20]
        ]
        return None, BorrowerClarification(
            message="Which borrower do you mean?",
            options=options,
        )
    if not exact and refers_to_previous and len(borrowers) == 1:
        return borrowers[0], None
    matches = (
        exact
        or partial
        or [
            item[1]
            for item in sorted(scored, key=lambda item: item[0], reverse=True)[:5]
        ]
    )
    if not matches:
        raise BorrowerNotFound(
            "I couldn't identify the borrower. Include their full name and try again."
        )
    if len(matches) == 1:
        return matches[0], None
    options = [
        BorrowerClarificationOption(
            borrower_id=item.id,
            display_name=f"{item.first_name} {item.last_name}".strip(),
            masked_reference=f"Borrower ••••{item.id[-4:]}",
        )
        for item in matches[:20]
    ]
    return None, BorrowerClarification(
        message="Multiple authorized borrowers match. Select the correct borrower.",
        options=options,
    )


def apply_admin_borrower_scope(statement: Any) -> Any:
    """Apply the reusable current-admin borrower authorization scope."""
    return statement.where(Borrower.status != "Deleted")


def _borrower_name_tokens(message: str) -> list[str]:
    stopwords = {
        "a",
        "about",
        "borrow",
        "borrowed",
        "borrower",
        "by",
        "did",
        "does",
        "due",
        "for",
        "history",
        "how",
        "installment",
        "is",
        "loan",
        "much",
        "next",
        "of",
        "owe",
        "owes",
        "payment",
        "principal",
        "show",
        "still",
        "summary",
        "the",
        "their",
        "they",
        "what",
    }
    return [
        token for token in message.split() if len(token) >= 2 and token not in stopwords
    ][:8]


async def _operational_records(
    db: AsyncSession,
    *,
    due_on: date | None = None,
    overdue_before: date | None = None,
    offset: int = 0,
) -> tuple[list[AdminAssistantRecord], int, Decimal]:
    conditions = [
        Installment.status.not_in({"Paid", "Cancelled"}),
        Installment.expected_payment > Installment.paid_amount,
    ]
    if due_on:
        conditions.append(Installment.due_date == due_on)
    if overdue_before:
        conditions.append(Installment.due_date < overdue_before)
    count, amount = (
        await db.execute(
            select(
                func.count(Installment.id),
                func.coalesce(
                    func.sum(Installment.expected_payment - Installment.paid_amount),
                    ZERO,
                ),
            ).where(*conditions)
        )
    ).one()
    rows = list(
        (
            await db.execute(
                select(Installment)
                .join(Installment.loan)
                .options(selectinload(Installment.loan).selectinload(Loan.borrower))
                .where(*conditions)
                .order_by(Installment.due_date, Installment.id)
                .offset(offset)
                .limit(_DISPLAY_LIMIT)
            )
        ).scalars()
    )
    records = [
        AdminAssistantRecord(
            borrower_id=item.loan.borrower.id,
            borrower_name=(
                f"{item.loan.borrower.first_name} {item.loan.borrower.last_name}"
            ).strip(),
            loan_id=item.loan.id,
            amount_due=f"{item.expected_payment - item.paid_amount:.2f}",
            due_date=item.due_date,
            status=item.status,
        )
        for item in rows
    ]
    return records, int(count or 0), Decimal(amount or ZERO)


async def _borrower_directory(
    db: AsyncSession,
    message: str,
    offset: int = 0,
) -> tuple[list[AdminAssistantRecord], int]:
    """Return a bounded, admin-only directory without sensitive identifiers."""
    conditions = [Borrower.status != "Deleted"]
    search_match = re.search(
        r"(?:find|search(?:\s+for)?|hanapin)\s+(?:the\s+)?borrower\s+(.+)",
        message,
        flags=re.IGNORECASE,
    )
    if search_match:
        search = re.sub(r"[^a-zA-Z0-9 '\-]", "", search_match.group(1)).strip()
        if search:
            pattern = f"%{search}%"
            conditions.append(
                or_(
                    Borrower.first_name.ilike(pattern),
                    Borrower.last_name.ilike(pattern),
                    (Borrower.first_name + " " + Borrower.last_name).ilike(pattern),
                )
            )
    total = await db.scalar(select(func.count(Borrower.id)).where(*conditions))
    borrowers = list(
        (
            await db.execute(
                select(Borrower)
                .where(*conditions)
                .order_by(Borrower.last_name, Borrower.first_name)
                .offset(offset)
                .limit(_DISPLAY_LIMIT)
            )
        ).scalars()
    )
    records = [
        AdminAssistantRecord(
            borrower_id=borrower.id,
            borrower_name=f"{borrower.first_name} {borrower.last_name}".strip(),
            status=borrower.status,
            record_type="borrower",
        )
        for borrower in borrowers
    ]
    return records, int(total or 0)


async def _borrower_facts(
    db: AsyncSession,
    borrower: Borrower,
    intent: AssistantIntent,
    as_of: date,
    offset: int = 0,
) -> tuple[dict[str, str | int], list[AdminAssistantRecord], AnonymousAIPayload | None]:
    loans = list(
        (
            await db.execute(
                select(Loan)
                .options(
                    selectinload(Loan.installments),
                    selectinload(Loan.payments),
                )
                .where(Loan.borrower_id == borrower.id)
                .order_by(Loan.created_at.desc())
            )
        ).scalars()
    )
    active = [loan for loan in loans if loan.status not in {"Paid", "Cancelled"}]
    original_principal = sum((loan.original_principal for loan in active), ZERO)
    outstanding = sum((loan.outstanding_principal for loan in active), ZERO)
    payments = [payment for loan in loans for payment in loan.payments]
    total_paid = sum(
        (
            payment.amount if payment.entry_type == "Payment" else -payment.amount
            for payment in payments
        ),
        ZERO,
    )
    unpaid = [
        item
        for loan in active
        for item in loan.installments
        if item.status not in {"Paid", "Cancelled"}
        and item.expected_payment > item.paid_amount
    ]
    overdue = [item for item in unpaid if item.due_date < as_of]
    next_item = min(unpaid, key=lambda item: item.due_date, default=None)
    metrics: dict[str, str | int] = {
        "borrowerName": f"{borrower.first_name} {borrower.last_name}".strip(),
        "originalPrincipal": f"{original_principal:.2f}",
        "outstandingBalance": f"{outstanding:.2f}",
        "totalPaid": f"{total_paid:.2f}",
        "activeLoanCount": len(active),
        "overdueInstallments": len(overdue),
        "nextDueDate": next_item.due_date.isoformat() if next_item else "None",
        "nextAmountDue": (
            f"{next_item.expected_payment - next_item.paid_amount:.2f}"
            if next_item
            else "0.00"
        ),
        "paymentRecordCount": len(payments),
    }
    records: list[AdminAssistantRecord] = []
    if intent == "borrower_overdue_installments":
        records = [
            AdminAssistantRecord(
                borrower_id=borrower.id,
                borrower_name=metrics["borrowerName"].__str__(),
                loan_id=item.loan_id,
                amount_due=f"{item.expected_payment - item.paid_amount:.2f}",
                due_date=item.due_date,
                status=item.status,
            )
            for item in sorted(overdue, key=lambda value: value.due_date)[
                offset : offset + _DISPLAY_LIMIT
            ]
        ]
    elif intent == "borrower_payment_history":
        records = [
            AdminAssistantRecord(
                borrower_id=borrower.id,
                borrower_name=metrics["borrowerName"].__str__(),
                loan_id=item.loan_id,
                status=item.entry_type,
                record_type="payment",
                amount_paid=f"{item.amount:.2f}",
                effective_date=item.effective_date,
            )
            for item in sorted(
                payments, key=lambda value: value.effective_date, reverse=True
            )[offset : offset + _DISPLAY_LIMIT]
        ]
    ai_payload = None
    if intent == "borrower_loan_summary":
        ai_payload = AnonymousAIPayload(
            intent="borrower_loan_summary",
            currency="",
            loan_status=active[0].status if active else "No active loan",
            outstanding_balance=f"{outstanding:.2f}",
            total_paid=f"{total_paid:.2f}",
            overdue_installments=len(overdue),
            next_due_date=next_item.due_date if next_item else None,
        )
    return metrics, records, ai_payload


def _local_answer(
    intent: AssistantIntent, metrics: dict[str, str | int], currency: str
) -> str:
    money = lambda value: f"{currency} {value}"  # noqa: E731
    if intent == "help":
        return (
            "Hello. Ask about collections, portfolio performance, due or overdue "
            "accounts, or a borrower's balance, next payment, history, or loan summary."
        )
    if intent == "collections_this_month":
        return (
            f"Collections this month total {money(metrics['collections'])}, including "
            f"{money(metrics['interestEarned'])} in interest income."
        )
    if intent == "portfolio_summary":
        return (
            f"Outstanding portfolio is {money(metrics['outstandingBalance'])}, with "
            f"{metrics['activeLoans']} active and {metrics['overdueLoans']} overdue loans."
        )
    if intent == "borrower_directory":
        count = int(metrics["recordCount"])
        if count == 0:
            return "No active borrower records were found."
        noun = "borrower" if count == 1 else "borrowers"
        return (
            f"I found {count} active {noun}. Select a borrower to open their profile."
        )
    if intent in {"unpaid_today", "due_tomorrow", "overdue"}:
        label = {
            "unpaid_today": "unpaid installments due today",
            "due_tomorrow": "installments due tomorrow",
            "overdue": "overdue installments",
        }[intent]
        return (
            f"There are {metrics['recordCount']} {label}, totaling "
            f"{money(metrics['amountDue'])}."
        )
    name = metrics["borrowerName"]
    if intent == "borrower_balance":
        return f"{name} has an outstanding balance of {money(metrics['outstandingBalance'])}."
    if intent == "borrower_principal":
        if int(metrics["activeLoanCount"]) == 0:
            return f"{name} has no active loan."
        return (
            f"{name}'s original principal across active loans is "
            f"{money(metrics['originalPrincipal'])}."
        )
    if intent == "borrower_next_payment":
        if metrics["nextDueDate"] == "None":
            return f"{name} has no unpaid scheduled installment."
        return (
            f"{name}'s next payment is {money(metrics['nextAmountDue'])} "
            f"due on {metrics['nextDueDate']}."
        )
    if intent == "borrower_overdue_installments":
        return (
            f"{name} has {metrics['overdueInstallments']} overdue installments "
            f"and {money(metrics['outstandingBalance'])} outstanding."
        )
    if intent == "borrower_payment_history":
        return f"{name} has {metrics['paymentRecordCount']} payment ledger entries."
    return (
        f"{name} has {metrics['activeLoanCount']} active loans, "
        f"{money(metrics['outstandingBalance'])} outstanding, and "
        f"{metrics['overdueInstallments']} overdue installments."
    )


async def answer_admin_question(
    db: AsyncSession,
    message: str,
    settings: Settings,
    *,
    selected_borrower_id: str | None = None,
    today: date | None = None,
    offset: int = 0,
) -> AdminAssistantResponse:
    """Orchestrate one approved query; AI failure can never fail the answer."""
    started = monotonic()
    as_of = today or business_date(settings)
    route = route_question(message)
    intent = route.intent
    currency = settings.currency_code
    if hasattr(db, "scalar"):
        configured_currency = await db.scalar(
            select(BusinessSetting.currency_code).limit(1)
        )
        if configured_currency:
            currency = configured_currency
    metrics: dict[str, str | int]
    records: list[AdminAssistantRecord] = []
    clarification = None
    total_count = 0
    ai_payload: AnonymousAIPayload | None = None

    if intent in _BORROWER_INTENTS:
        borrower, clarification = await _resolve_borrower(
            db, message, selected_borrower_id
        )
        if clarification:
            return AdminAssistantResponse(
                intent=intent,
                matched_route=route.route,
                intent_confidence=route.confidence,
                answer=clarification.message,
                metrics={},
                clarification=clarification,
                as_of=as_of,
                generated_at=datetime.now(UTC),
                currency=currency,
            )
        assert borrower is not None
        metrics, records, ai_payload = await _borrower_facts(
            db, borrower, intent, as_of, offset
        )
        total_count = (
            int(metrics["overdueInstallments"])
            if intent == "borrower_overdue_installments"
            else int(metrics["paymentRecordCount"])
            if intent == "borrower_payment_history"
            else len(records)
        )
    elif intent == "help":
        metrics = {"supportedTopics": 11}
    elif intent == "borrower_directory":
        records, total_count = await _borrower_directory(db, message, offset)
        metrics = {"recordCount": total_count}
    elif intent == "collections_this_month":
        start = as_of.replace(day=1)
        report = await projection_service.financial_report(db, start, as_of)
        metrics = {
            "collections": f"{report.collections:.2f}",
            "interestEarned": f"{report.interest_earned:.2f}",
            "principalCollected": f"{report.principal_collected:.2f}",
            "period": f"{start.isoformat()} to {as_of.isoformat()}",
        }
    elif intent == "portfolio_summary":
        dashboard = await projection_service.dashboard(db, as_of)
        metrics = {
            "outstandingBalance": f"{dashboard.outstanding_balance:.2f}",
            "activeLoans": dashboard.active_loans,
            "overdueLoans": dashboard.overdue_loans,
            "dueToday": f"{dashboard.due_today:.2f}",
        }
        ai_payload = AnonymousAIPayload(
            intent="portfolio_summary",
            currency=currency,
            outstanding_balance=metrics["outstandingBalance"].__str__(),
            active_loans=dashboard.active_loans,
            overdue_loans=dashboard.overdue_loans,
            due_today=metrics["dueToday"].__str__(),
        )
    else:
        records, total_count, total = await _operational_records(
            db,
            due_on=(
                as_of
                if intent == "unpaid_today"
                else as_of + timedelta(days=1)
                if intent == "due_tomorrow"
                else None
            ),
            overdue_before=as_of if intent == "overdue" else None,
            offset=offset,
        )
        metrics = {
            "recordCount": total_count,
            "amountDue": f"{total:.2f}",
            "asOf": as_of.isoformat(),
        }

    if ai_payload and not ai_payload.currency:
        ai_payload = ai_payload.model_copy(update={"currency": currency})
    local_answer = _local_answer(intent, metrics, currency)
    enhanced = None
    ai_status = "skipped"
    if ai_payload and should_use_ai(intent, metrics):
        enhanced, ai_status = await _enhance_with_ai(ai_payload, settings)
    answer = f"{local_answer} {enhanced}".strip() if enhanced else local_answer
    logger.info(
        "assistant_answer",
        extra={
            "intent": intent,
            "answer_source": "ai_enhanced" if enhanced else "local",
            "ai_status": ai_status,
            "record_count": total_count,
            "latency_ms": int((monotonic() - started) * 1000),
        },
    )
    return AdminAssistantResponse(
        intent=intent,
        matched_route=route.route,
        intent_confidence=route.confidence,
        answer=answer,
        metrics=metrics,
        records=records,
        clarification=clarification,
        as_of=as_of,
        generated_at=datetime.now(UTC),
        answer_source="ai_enhanced" if enhanced else "local",
        ai_used=enhanced is not None,
        ai_status=ai_status,
        total_matching_count=total_count,
        returned_record_count=len(records),
        has_more=total_count > offset + len(records),
        next_offset=(
            offset + len(records) if total_count > offset + len(records) else None
        ),
        currency=currency,
    )
