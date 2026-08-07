"""Granular role-permission and maker-checker tests."""

import unittest
from types import SimpleNamespace

from app.core.authorization import (
    PERMISSIONS,
    permissions_for,
    require_permission,
)


class AuthorizationMatrixTests(unittest.TestCase):
    def test_owner_has_every_declared_permission(self) -> None:
        self.assertEqual(permissions_for("owner"), PERMISSIONS)

    def test_collector_cannot_approve_reconciliation(self) -> None:
        with self.assertRaises(Exception) as raised:
            require_permission(
                SimpleNamespace(role="collector"), "reconciliation.approve"
            )
        self.assertEqual(raised.exception.status_code, 403)

    def test_auditor_can_view_but_cannot_post_accounting(self) -> None:
        require_permission(SimpleNamespace(role="auditor"), "accounting.view")
        with self.assertRaises(Exception):
            require_permission(
                SimpleNamespace(role="auditor"), "accounting.post_adjustment"
            )

    def test_unknown_role_has_no_permissions(self) -> None:
        self.assertEqual(permissions_for("unexpected"), frozenset())
