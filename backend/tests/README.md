# Backend Tests

The backend uses Python's built-in `unittest` framework. No additional test
package is required.

Run all backend tests from `backend/`:

```powershell
python -m unittest discover -s tests -v
```

Test files follow the `test_*.py` naming convention. Loan-calculation tests use
`Decimal` values created from strings so money is represented exactly.

## Verified calculation foundation

Verified on 2026-07-19:

- 15 backend unit tests pass;
- 28 backend application, migration, and test files parse successfully;
- Alembic reports no new upgrade operations;
- 12 Flutter tests pass; and
- Flutter analysis reports no issues.

The verified backend scenarios include scheduled and prorated interest,
interest-first allocation, underpayment, overpayment credit, reducing-balance
partial payments, interest-only payments, early and late payoff, and a
ten-installment schedule with a final-payment adjustment.
