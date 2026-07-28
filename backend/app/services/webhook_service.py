"""Asynchronous webhook dispatcher service for n8n integration using Python standard library."""

import asyncio
import json
import logging
import urllib.request
from typing import Any

from app.config import get_settings

logger = logging.getLogger(__name__)


def _send_http_post(
    url: str, data_bytes: bytes, headers: dict[str, str]
) -> tuple[int, str]:
    req = urllib.request.Request(url, data=data_bytes, headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=5.0) as response:
        return response.getcode(), response.read().decode("utf-8")


async def dispatch_n8n_event(event_name: str, payload: dict[str, Any]) -> None:
    """Send an event payload to the configured n8n webhook endpoint.

    Fails gracefully without throwing exceptions to avoid breaking caller operations.
    """
    settings = get_settings()
    webhook_url = settings.n8n_webhook_url

    if not webhook_url:
        logger.debug(
            "n8n webhook URL not configured. Skipping event dispatch for '%s'.",
            event_name,
        )
        return

    headers = {
        "Content-Type": "application/json",
        "User-Agent": "LendingNelson-Backend/1.0",
    }
    if settings.n8n_webhook_secret:
        headers["X-Webhook-Secret"] = settings.n8n_webhook_secret

    body = {
        "event": event_name,
        "payload": payload,
    }
    data_bytes = json.dumps(body).encode("utf-8")

    try:
        status_code, resp_text = await asyncio.to_thread(
            _send_http_post, webhook_url, data_bytes, headers
        )
        if 200 <= status_code < 300:
            logger.info("Successfully dispatched event '%s' to n8n.", event_name)
        else:
            logger.warning(
                "n8n webhook returned status code %d for event '%s'. Response: %s",
                status_code,
                event_name,
                resp_text,
            )
    except Exception as exc:
        logger.error("Failed to dispatch n8n event '%s': %s", event_name, str(exc))
