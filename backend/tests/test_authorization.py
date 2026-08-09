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

    def test_auditor_cannot_view_or_post_accounting(self) -> None:
        with self.assertRaises(Exception) as raised1:
            require_permission(SimpleNamespace(role="auditor"), "accounting.view")
        self.assertEqual(raised1.exception.status_code, 403)

        with self.assertRaises(Exception) as raised2:
            require_permission(
                SimpleNamespace(role="auditor"), "accounting.post_adjustment"
            )
        self.assertEqual(raised2.exception.status_code, 403)

    def test_unknown_role_has_no_permissions(self) -> None:
        self.assertEqual(permissions_for("unexpected"), frozenset())
