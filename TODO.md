# Lending Nelson TODO

Only the current step is shown here. Complete and verify it before adding the
next step.

Long-term work remains in the [Product Roadmap](docs/roadmap/README.md).

## Step 5: Connect Flutter to backend loans

Goal: let an authenticated officer create and inspect borrower loans from the
Flutter application using the tested FastAPI loan endpoints.

1. [x] Add immutable Flutter loan and installment models with JSON conversion.
2. [x] Add repository methods for loan creation, listing, and detail requests.
3. [x] Add a borrower loan list and navigation to loan creation and details.
4. [x] Add a validated create-loan form and installment-schedule detail screen.
5. [x] Add Flutter tests, run all checks, update student docs, and commit Step 5.

Version-one frontend rules:

- Flutter sends exact money and rate values as decimal strings;
- every new loan starts from an existing borrower;
- the lender chooses the monthly interest rate and repayment terms;
- the backend remains the source of truth for all calculations;
- Flutter displays the persisted schedule instead of recalculating it;
- monthly and twice-monthly schedules are supported by the initial UI; and
- API failures produce clear, actionable messages without losing form input.

Step 5 is complete only when an officer can open a borrower, create a loan, and
view the backend-generated installment schedule in Flutter. After that, replace
this step with Step 6.
