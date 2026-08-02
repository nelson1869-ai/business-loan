"""Security and historical-integrity tests for versioned loan policies."""

import unittest
from datetime import UTC, date, datetime
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

from app.features.loan_policies.models import LoanPolicyVersion
from app.features.loan_policies.router import _require_admin
from app.features.loan_policies.schemas import LoanPolicyCreate
from app.features.loan_policies.service import activate_policy, policy_snapshot
from app.features.loans.schemas import LoanCreate
from app.features.loans.service import create_loan


def _policy(*, status: str = "draft", maker: str = "maker") -> LoanPolicyVersion:
    return LoanPolicyVersion(
        id="00000000-0000-4000-8000-000000000901",
        policy_name="Standard Microloan",
        version_number=1,
        status=status,
        currency="PHP",
        interest_method="fixed_periodic_reducing_balance",
        rate_period="monthly",
        minimum_rate=Decimal("0.01"),
        maximum_rate=Decimal("0.10"),
        rounding_policy={"mode": "ROUND_HALF_UP", "scale": 2},
        payment_allocation_order=["interest", "principal", "unapplied_credit"],
        grace_period_configuration={"enabled": False},
        late_fee_configuration={"enabled": False},
        early_settlement_configuration={"enabled": True},
        excess_payment_treatment={"mode": "unapplied_credit"},
        restructuring_policy={"enabled": False},
        write_off_policy={"enabled": False},
        contract_template_version="v1",
        effective_date=date(2026, 8, 2),
        change_reason="Initial controlled policy",
        created_by_user_id=maker,
        created_at=datetime.now(UTC),
    )


class LoanPolicySchemaTests(unittest.TestCase):
    def test_binary_float_rates_are_rejected(self) -> None:
        with self.assertRaises(ValueError):
            LoanPolicyCreate(
                policyName="Policy",
                versionNumber=1,
                currency="php",
                minimumRate=0.01,
                maximumRate="0.10",
                roundingPolicy={"mode": "ROUND_HALF_UP"},
                paymentAllocationOrder=["interest", "principal"],
                gracePeriodConfiguration={},
                lateFeeConfiguration={"enabled": False},
                earlySettlementConfiguration={},
                excessPaymentTreatment={},
                restructuringPolicy={"enabled": False},
                writeOffPolicy={"enabled": False},
                contractTemplateVersion="v1",
                effectiveDate="2026-08-02",
                changeReason="Test",
            )

    def test_snapshot_is_detached_from_later_policy_changes(self) -> None:
        policy = _policy(status="active")
        snapshot = policy_snapshot(policy)
        policy.status = "retired"
        policy.maximum_rate = Decimal("0.20")
        self.assertEqual(snapshot["maximumRate"], "0.10")
        self.assertEqual(snapshot["versionNumber"], 1)


class LoanPolicyApprovalTests(unittest.IsolatedAsyncioTestCase):
    def test_non_admin_cannot_administer_policies(self) -> None:
        with self.assertRaises(Exception) as raised:
            _require_admin(SimpleNamespace(role="officer"))
        self.assertEqual(raised.exception.status_code, 403)

    async def test_maker_cannot_activate_own_policy(self) -> None:
        db = MagicMock()
        db.execute = AsyncMock()
        result = MagicMock()
        result.scalar_one_or_none.return_value = _policy(maker="same-user")
        db.execute.return_value = result
        checker = SimpleNamespace(id="same-user")

        with self.assertRaises(PermissionError):
            await activate_policy(db, "policy-id", checker, "approve")

    async def test_checker_activation_is_audited(self) -> None:
        db = MagicMock()
        db.execute = AsyncMock()
        db.flush = AsyncMock()
        result = MagicMock()
        policy = _policy(maker="maker-user")
        result.scalar_one_or_none.return_value = policy
        db.execute.return_value = result
        checker = SimpleNamespace(id="checker-user")

        activated = await activate_policy(db, policy.id, checker, "reviewed")

        self.assertEqual(activated.status, "active")
        self.assertEqual(activated.approved_by_user_id, "checker-user")
        self.assertTrue(
            any(
                getattr(item, "action", "") == "POLICY_ACTIVATE"
                for item in (call.args[0] for call in db.add.call_args_list)
            )
        )
        db.flush.assert_awaited_once()

    async def test_retired_policy_cannot_be_activated_again(self) -> None:
        db = MagicMock()
        db.execute = AsyncMock()
        result = MagicMock()
        result.scalar_one_or_none.return_value = _policy(status="retired")
        db.execute.return_value = result

        with self.assertRaisesRegex(ValueError, "draft"):
            await activate_policy(
                db, "policy-id", SimpleNamespace(id="checker"), "retry"
            )

    async def test_draft_policy_cannot_be_attached_to_new_loan(self) -> None:
        db = MagicMock()
        db.get = AsyncMock(return_value=_policy(status="draft"))
        payload = LoanCreate(
            borrowerId="00000000-0000-4000-8000-000000000001",
            policyVersionId="00000000-0000-4000-8000-000000000901",
            originalPrincipal="1000.00",
            monthlyRate="0.05",
            termMonths=1,
            paymentsPerMonth=1,
            startDate="2026-08-02",
            firstDueDate="2026-09-02",
        )

        with self.assertRaisesRegex(ValueError, "active loan policy"):
            await create_loan(db, payload, SimpleNamespace(id="officer"))
