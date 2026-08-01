"""Backward-compatibility checks for Alembic's aggregate model namespace."""

from app.features.loans.models import Loan as FeatureLoan
from app.features.payments.models import Payment as FeaturePayment
from app.models import Loan, Payment


def test_legacy_model_exports_reference_feature_models() -> None:
    """Keep existing Alembic and external model imports resolving identically."""
    assert Loan is FeatureLoan
    assert Payment is FeaturePayment
