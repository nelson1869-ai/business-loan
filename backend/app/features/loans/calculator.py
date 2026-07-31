"""Loan calculator forwarder."""

from app.services.loan_calculator import (
    calculate_fixed_reducing_balance_schedule,
    generate_schedule,
)

__all__ = [
    "calculate_fixed_reducing_balance_schedule",
    "generate_schedule",
]
