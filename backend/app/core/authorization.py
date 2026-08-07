"""Central role-to-permission policy for officer APIs."""

from collections.abc import Iterable

from fastapi import HTTPException

PERMISSIONS = frozenset(
    {
        "borrower.create",
        "borrower.update",
        "borrower.archive",
        "loan.create",
        "loan.approve",
        "loan.disburse",
        "loan.restructure",
        "loan.write_off",
        "payment.collect",
        "payment.reverse",
        "receipt.reprint",
        "accounting.view",
        "accounting.post_adjustment",
        "reconciliation.submit",
        "reconciliation.approve",
        "report.view",
        "report.export",
        "policy.create",
        "policy.approve",
        "user.manage",
        "audit.view",
        "borrower_registration.review",
        "borrower_account.manage",
    }
)

ROLE_PERMISSIONS: dict[str, frozenset[str]] = {
    "admin": PERMISSIONS,
    "owner": PERMISSIONS,
    "manager": PERMISSIONS - {"user.manage", "borrower_account.manage"},
    "officer": frozenset(
        {
            "borrower.create",
            "borrower.update",
            "loan.create",
            "payment.collect",
            "receipt.reprint",
            "reconciliation.submit",
            "report.view",
        }
    ),
    "loan_officer": frozenset(
        {
            "borrower.create",
            "borrower.update",
            "loan.create",
            "payment.collect",
            "receipt.reprint",
            "report.view",
        }
    ),
    "collector": frozenset(
        {"payment.collect", "receipt.reprint", "reconciliation.submit"}
    ),
    "cashier": frozenset(
        {
            "payment.collect",
            "receipt.reprint",
            "reconciliation.submit",
            "reconciliation.approve",
            "accounting.view",
            "report.view",
        }
    ),
    "auditor": frozenset(
        {"accounting.view", "report.view", "report.export", "audit.view"}
    ),
    "read_only_support": frozenset({"report.view"}),
}


def permissions_for(role: str) -> frozenset[str]:
    return ROLE_PERMISSIONS.get(role, frozenset())


def has_permission(user: object, permission: str) -> bool:
    return permission in permissions_for(str(getattr(user, "role", "")))


def require_permission(user: object, permission: str) -> None:
    if not has_permission(user, permission):
        raise HTTPException(
            status_code=403, detail=f"Permission required: {permission}"
        )


def require_any_permission(user: object, permissions: Iterable[str]) -> None:
    granted = permissions_for(str(getattr(user, "role", "")))
    if granted.isdisjoint(permissions):
        raise HTTPException(status_code=403, detail="Required permission not granted")


def require_owner(user: object) -> None:
    """Enforce that the authenticated user possesses the owner or admin role."""
    role = str(getattr(user, "role", "")).lower()
    if role not in {"owner", "admin"}:
        raise HTTPException(
            status_code=403, detail="Owner authorization required"
        )

