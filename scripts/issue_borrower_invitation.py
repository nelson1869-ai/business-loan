"""Issue a borrower-portal activation code without exposing admin tokens."""

from __future__ import annotations

import argparse
import getpass
import json
import sys
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen
from uuid import UUID


def _post_json(
    url: str,
    payload: dict[str, Any],
    *,
    access_token: str | None = None,
) -> dict[str, Any]:
    headers = {
        "Accept": "application/json",
        "Content-Type": "application/json",
    }
    if access_token:
        headers["Authorization"] = f"Bearer {access_token}"
    request = Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        with urlopen(request, timeout=15) as response:
            return json.loads(response.read().decode("utf-8"))
    except HTTPError as error:
        try:
            body = json.loads(error.read().decode("utf-8"))
            detail = body.get("detail", "Request was rejected")
        except (UnicodeDecodeError, json.JSONDecodeError):
            detail = "Request was rejected"
        raise RuntimeError(f"HTTP {error.code}: {detail}") from error
    except URLError as error:
        raise RuntimeError(f"Cannot connect to the backend: {error.reason}") from error


def _validate_api_url(value: str) -> str:
    url = value.rstrip("/")
    parsed = urlparse(url)
    local_hosts = {"127.0.0.1", "localhost", "::1"}
    if parsed.scheme == "https":
        return url
    if parsed.scheme == "http" and parsed.hostname in local_hosts:
        return url
    raise argparse.ArgumentTypeError(
        "Use HTTPS, or HTTP only for localhost development"
    )


def _borrower_id(value: str) -> str:
    try:
        return str(UUID(value))
    except ValueError as error:
        raise argparse.ArgumentTypeError("borrower ID must be a UUID") from error


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate a one-time borrower portal activation code.",
    )
    parser.add_argument("borrower_id", type=_borrower_id)
    parser.add_argument("--username", default="nelson-admin")
    parser.add_argument(
        "--api-url",
        type=_validate_api_url,
        default="http://127.0.0.1:8000",
    )
    parser.add_argument("--expires-hours", type=int, default=72, choices=range(1, 721))
    return parser


def main() -> int:
    args = build_parser().parse_args()
    password = getpass.getpass(f"Admin password for {args.username}: ")
    if not password:
        print("Error: password is required", file=sys.stderr)
        return 2

    try:
        login = _post_json(
            f"{args.api_url}/api/v1/auth/token",
            {"username": args.username, "password": password},
        )
        access_token = login.get("access_token")
        if not isinstance(access_token, str) or not access_token:
            raise RuntimeError("Backend did not return an access token")

        invitation = _post_json(
            f"{args.api_url}/api/v1/borrowers/{args.borrower_id}/client-invitation",
            {"expiresInHours": args.expires_hours},
            access_token=access_token,
        )
    except RuntimeError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    finally:
        password = ""

    print()
    print("============================================")
    print("BORROWER PORTAL ACTIVATION")
    print("============================================")
    print(f"Borrower ID:     {invitation.get('borrowerId', args.borrower_id)}")
    print(f"Activation Code: {invitation.get('invitationCode', '[missing]')}")
    print(f"Expires At:      {invitation.get('expiresAt', '[missing]')}")
    print("============================================")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
